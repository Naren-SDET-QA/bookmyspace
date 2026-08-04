-- ============================================================
-- Venue Import Engine: staging, review, publish, claim flow
-- Compliant OSM/Google sources; admin-only staging mutations
-- ============================================================

-- ------------------------------------------------------------
-- ENUMS
-- ------------------------------------------------------------
create type public.venue_import_job_status as enum (
  'pending',
  'fetching',
  'review',
  'completed',
  'failed'
);

create type public.venue_import_staging_status as enum (
  'pending_review',
  'approved',
  'rejected',
  'published',
  'duplicate'
);

create type public.venue_claim_status as enum (
  'pending',
  'approved',
  'rejected'
);

-- ------------------------------------------------------------
-- CATEGORY MAPPING CONFIG (OSM / Google taxonomy)
-- ------------------------------------------------------------
create table public.venue_import_category_mappings (
  id uuid primary key default gen_random_uuid(),
  category_slug text not null references public.venue_categories(slug) on update cascade,
  osm_tags jsonb not null default '[]'::jsonb,
  google_place_type text,
  display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (category_slug)
);

-- ------------------------------------------------------------
-- IMPORT JOBS
-- ------------------------------------------------------------
create table public.venue_import_jobs (
  id uuid primary key default gen_random_uuid(),
  country text not null,
  state text not null,
  category_slug text not null references public.venue_categories(slug) on update cascade,
  status public.venue_import_job_status not null default 'pending',
  source text not null default 'osm',
  venues_fetched integer not null default 0,
  venues_staged integer not null default 0,
  venues_duplicates integer not null default 0,
  error_message text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

-- ------------------------------------------------------------
-- STAGING TABLE
-- ------------------------------------------------------------
create table public.venue_import_staging (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.venue_import_jobs(id) on delete cascade,
  status public.venue_import_staging_status not null default 'pending_review',
  name text not null,
  category_slug text not null,
  address_line1 text,
  address_line2 text,
  city text,
  district text,
  state text,
  postal_code text,
  country text not null default 'IN',
  phone text,
  website text,
  latitude double precision not null,
  longitude double precision not null,
  source text not null,
  source_place_id text,
  osm_id text,
  operating_hours jsonb not null default '[]'::jsonb,
  amenities jsonb not null default '[]'::jsonb,
  ratings jsonb not null default '{}'::jsonb,
  image_refs jsonb not null default '[]'::jsonb,
  raw_payload jsonb,
  duplicate_of_staging_id uuid references public.venue_import_staging(id),
  duplicate_of_venue_id uuid references public.venues(id),
  published_venue_id uuid references public.venues(id),
  fetched_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_venue_import_staging_job on public.venue_import_staging(job_id);
create index idx_venue_import_staging_status on public.venue_import_staging(status);
create index idx_venue_import_staging_source_place on public.venue_import_staging(source, source_place_id)
  where source_place_id is not null;
create index idx_venue_import_staging_name_loc on public.venue_import_staging(
  lower(trim(name)), round(latitude::numeric, 3), round(longitude::numeric, 3)
);

-- ------------------------------------------------------------
-- VENUE CLAIMS (Claim This Venue)
-- ------------------------------------------------------------
create table public.venue_claims (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  claimant_user_id uuid not null references auth.users(id) on delete cascade,
  status public.venue_claim_status not null default 'pending',
  evidence jsonb not null default '{}'::jsonb,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, claimant_user_id)
);

create index idx_venue_claims_venue on public.venue_claims(venue_id);
create index idx_venue_claims_status on public.venue_claims(status);

-- ------------------------------------------------------------
-- VENUES: import metadata + owner-verified locks
-- ------------------------------------------------------------
alter table public.venues
  add column if not exists data_source text,
  add column if not exists source_place_id text,
  add column if not exists source_fetched_at timestamptz,
  add column if not exists owner_verified_fields jsonb not null default '[]'::jsonb,
  add column if not exists is_claimable boolean not null default false,
  add column if not exists import_staging_id uuid references public.venue_import_staging(id);

create unique index if not exists idx_venues_source_place_id
  on public.venues(data_source, source_place_id)
  where source_place_id is not null and data_source is not null and deleted_at is null;

create trigger trg_venue_import_staging_updated_at
  before update on public.venue_import_staging
  for each row execute function public.set_updated_at();

create trigger trg_venue_claims_updated_at
  before update on public.venue_claims
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- SEED: category mappings
-- ------------------------------------------------------------
insert into public.venue_import_category_mappings (category_slug, osm_tags, google_place_type, display_name) values
  ('function_hall', '["amenity=events_venue","amenity=community_centre"]'::jsonb, 'event_venue', 'Function Hall'),
  ('marriage_hall', '["amenity=events_venue"]'::jsonb, 'event_venue', 'Marriage Hall'),
  ('convention_center', '["amenity=events_venue","building=convention_centre"]'::jsonb, 'convention_center', 'Convention Center'),
  ('party_hall', '["amenity=events_venue"]'::jsonb, 'event_venue', 'Party Hall'),
  ('meeting_room', '["amenity=conference_centre"]'::jsonb, 'conference_room', 'Meeting Room'),
  ('community_hall', '["amenity=community_centre"]'::jsonb, 'community_center', 'Community Hall'),
  ('sports_ground', '["leisure=sports_centre","sport"]'::jsonb, 'stadium', 'Sports Ground'),
  ('coworking_space', '["amenity=coworking_space"]'::jsonb, 'coworking_space', 'Coworking Space'),
  ('auditorium', '["amenity=theatre"]'::jsonb, 'performing_arts_theater', 'Auditorium')
on conflict (category_slug) do update set
  osm_tags = excluded.osm_tags,
  google_place_type = excluded.google_place_type,
  display_name = excluded.display_name;

-- Platform org for unclaimed imported listings (created when first admin exists).
do $$
declare
  v_admin uuid;
  v_org uuid := 'a1000000-0000-4000-8000-000000000001';
begin
  select ur.user_id into v_admin
  from public.user_roles ur
  where ur.role in ('administrator', 'super_administrator')
    and ur.revoked_at is null
  order by ur.granted_at
  limit 1;

  if v_admin is not null then
    insert into public.organizations (id, owner_user_id, org_type, name, legal_name, country, is_active)
    values (v_org, v_admin, 'venue_owner', 'BookMySpace Platform Listings',
            'BookMySpace Platform Listings', 'IN', true)
    on conflict (id) do nothing;
  end if;
end $$;

-- ------------------------------------------------------------
-- HELPERS
-- ------------------------------------------------------------
create or replace function public.is_admin_user(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    public.has_role(p_uid, 'administrator')
    or public.has_role(p_uid, 'super_administrator'),
    false
  );
$$;

create or replace function public.normalize_venue_phone(p_phone text)
returns text
language plpgsql
immutable
as $$
declare
  v_digits text;
begin
  if p_phone is null or trim(p_phone) = '' then return null; end if;
  v_digits := regexp_replace(p_phone, '[^0-9+]', '', 'g');
  if v_digits like '+91%' and length(v_digits) = 13 then
    return v_digits;
  end if;
  if length(regexp_replace(v_digits, '[^0-9]', '', 'g')) = 10 then
    return '+91' || regexp_replace(v_digits, '[^0-9]', '', 'g');
  end if;
  if v_digits like '+%' then return v_digits; end if;
  return v_digits;
end;
$$;

create or replace function public.normalize_venue_address(p_address text)
returns text
language sql
immutable
as $$
  select case
    when p_address is null then null
    else trim(regexp_replace(p_address, '\s+', ' ', 'g'))
  end;
$$;

create or replace function public.platform_import_org_id()
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_org uuid;
begin
  select id into v_org from public.organizations
  where id = 'a1000000-0000-4000-8000-000000000001'::uuid
    and deleted_at is null;
  if v_org is not null then return v_org; end if;

  select id into v_org from public.organizations
  where name = 'BookMySpace Platform Listings' and deleted_at is null
  limit 1;
  return v_org;
end;
$$;

-- ------------------------------------------------------------
-- ADMIN RPCs: job + staging workflow
-- ------------------------------------------------------------
create or replace function public.admin_create_venue_import_job(
  p_country text,
  p_state text,
  p_category_slug text,
  p_source text default 'osm'
)
returns public.venue_import_jobs
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_job public.venue_import_jobs;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  insert into public.venue_import_jobs (country, state, category_slug, source, created_by)
  values (trim(p_country), trim(p_state), trim(p_category_slug), coalesce(p_source, 'osm'), auth.uid())
  returning * into v_job;

  return v_job;
end;
$$;

create or replace function public.admin_review_staging_venue(
  p_staging_id uuid,
  p_approve boolean,
  p_notes text default null
)
returns public.venue_import_staging
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.venue_import_staging;
begin
  if not public.is_admin_user() then raise exception 'admin_required'; end if;

  update public.venue_import_staging
  set status = case when p_approve then 'approved'::public.venue_import_staging_status
                    else 'rejected'::public.venue_import_staging_status end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_notes = p_notes,
      updated_at = now()
  where id = p_staging_id
    and status in ('pending_review', 'approved', 'rejected')
  returning * into v_row;

  if v_row is null then raise exception 'staging_not_found_or_locked'; end if;
  return v_row;
end;
$$;

-- Publish approved staging row to venues; never overwrite owner-verified fields on re-import.
create or replace function public.admin_publish_staged_venue(p_staging_id uuid)
returns public.venues
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_staging public.venue_import_staging;
  v_venue public.venues;
  v_org uuid;
  v_category_id uuid;
  v_existing uuid;
  v_verified jsonb;
begin
  if not public.is_admin_user() then raise exception 'admin_required'; end if;

  select * into v_staging from public.venue_import_staging
  where id = p_staging_id and status = 'approved';
  if v_staging is null then raise exception 'staging_not_approved'; end if;

  v_org := public.platform_import_org_id();
  if v_org is null then raise exception 'platform_import_org_missing'; end if;

  select id into v_category_id from public.venue_categories
  where slug = v_staging.category_slug;

  -- Upsert by source place id when present.
  if v_staging.source_place_id is not null then
    select id, owner_verified_fields into v_existing, v_verified
    from public.venues
    where data_source = v_staging.source
      and source_place_id = v_staging.source_place_id
      and deleted_at is null
    limit 1;
  end if;

  if v_existing is null then
  insert into public.venues (
    org_id, category_id, name, slug,
    address_line1, address_line2, city, state, postal_code, country,
    latitude, longitude, capacity, pricing_base_amount,
    data_source, source_place_id, source_fetched_at,
    is_claimable, is_active, is_verified, import_staging_id
  ) values (
    v_org, v_category_id,
    v_staging.name,
    lower(regexp_replace(v_staging.name, '[^a-zA-Z0-9]+', '-', 'g')),
    coalesce(v_staging.address_line1, ''),
    v_staging.address_line2,
    coalesce(v_staging.city, v_staging.district),
    v_staging.state,
    v_staging.postal_code,
    v_staging.country,
    v_staging.latitude,
    v_staging.longitude,
    100,
    0,
    v_staging.source,
    v_staging.source_place_id,
    v_staging.fetched_at,
    true,
    true,
    false,
    v_staging.id
  ) returning * into v_venue;
  else
    v_verified := coalesce(v_verified, '[]'::jsonb);
    update public.venues v
    set
      name = case when v_verified ? 'name' then v.name else v_staging.name end,
      category_id = case when v_verified ? 'category_id' then v.category_id else v_category_id end,
      address_line1 = case when v_verified ? 'address_line1' then v.address_line1
                           else coalesce(v_staging.address_line1, v.address_line1) end,
      city = case when v_verified ? 'city' then v.city
                  else coalesce(v_staging.city, v_staging.district, v.city) end,
      state = case when v_verified ? 'state' then v.state else coalesce(v_staging.state, v.state) end,
      postal_code = case when v_verified ? 'postal_code' then v.postal_code
                         else coalesce(v_staging.postal_code, v.postal_code) end,
      latitude = case when v_verified ? 'latitude' then v.latitude else v_staging.latitude end,
      longitude = case when v_verified ? 'longitude' then v.longitude else v_staging.longitude end,
      source_fetched_at = v_staging.fetched_at,
      import_staging_id = v_staging.id,
      updated_at = now()
    where v.id = v_existing
    returning v.* into v_venue;
  end if;

  -- Images from legally usable OSM/Wikimedia refs (URLs only, no download).
  if jsonb_array_length(v_staging.image_refs) > 0 then
    insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
    select v_venue.id, ref->>'url', coalesce(ref->>'alt', v_staging.name), (ord = 1), ord - 1
    from jsonb_array_elements(v_staging.image_refs) with ordinality as t(ref, ord)
    where ref->>'url' is not null
    on conflict do nothing;
  end if;

  -- Amenities as facilities.
  if jsonb_array_length(v_staging.amenities) > 0 then
    insert into public.venue_facilities (venue_id, facility)
    select v_venue.id, amenity
    from jsonb_array_elements_text(v_staging.amenities) as amenity
  on conflict (venue_id, facility) do update set is_available = true;
  end if;

  update public.venue_import_staging
  set status = 'published',
      published_venue_id = v_venue.id,
      updated_at = now()
  where id = p_staging_id;

  return v_venue;
end;
$$;

-- ------------------------------------------------------------
-- CLAIM FLOW
-- ------------------------------------------------------------
create or replace function public.submit_venue_claim(
  p_venue_id uuid,
  p_evidence jsonb default '{}'::jsonb
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.venue_claims;
  v_claimable boolean;
begin
  select is_claimable into v_claimable from public.venues
  where id = p_venue_id and deleted_at is null and is_active;
  if not coalesce(v_claimable, false) then raise exception 'venue_not_claimable'; end if;

  insert into public.venue_claims (venue_id, claimant_user_id, evidence)
  values (p_venue_id, auth.uid(), coalesce(p_evidence, '{}'::jsonb))
  on conflict (venue_id, claimant_user_id) do update
    set evidence = excluded.evidence,
        status = 'pending',
        updated_at = now()
  returning * into v_claim;

  return v_claim;
end;
$$;

create or replace function public.admin_review_venue_claim(
  p_claim_id uuid,
  p_approve boolean,
  p_notes text default null
)
returns public.venue_claims
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_claim public.venue_claims;
  v_org uuid;
begin
  if not public.is_admin_user() then raise exception 'admin_required'; end if;

  select * into v_claim from public.venue_claims where id = p_claim_id and status = 'pending';
  if v_claim is null then raise exception 'claim_not_found'; end if;

  if p_approve then
    select id into v_org from public.organizations
    where owner_user_id = v_claim.claimant_user_id and deleted_at is null
    order by created_at limit 1;

    if v_org is null then
      insert into public.organizations (owner_user_id, org_type, name, country)
      values (v_claim.claimant_user_id, 'venue_owner',
              'Claimed Venue Organization', 'IN')
      returning id into v_org;
    end if;

    update public.venues
    set org_id = v_org,
        is_claimable = false,
        is_verified = true,
        owner_verified_fields = '["name","category_id","address_line1","city","state","postal_code","latitude","longitude","phone","website","description","capacity","pricing_base_amount"]'::jsonb,
        updated_at = now()
    where id = v_claim.venue_id;

    insert into public.user_roles (user_id, role, granted_by)
    values (v_claim.claimant_user_id, 'venue_owner', auth.uid())
    on conflict (user_id, role) do update set revoked_at = null;
  end if;

  update public.venue_claims
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_notes = p_notes,
      updated_at = now()
  where id = p_claim_id
  returning * into v_claim;

  return v_claim;
end;
$$;

-- Service role / edge function staging insert (dedupe aware).
create or replace function public.service_stage_import_venue(
  p_job_id uuid,
  p_payload jsonb
)
returns public.venue_import_staging
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_staging public.venue_import_staging;
  v_dup_staging uuid;
  v_dup_venue uuid;
  v_name text := trim(p_payload->>'name');
  v_source text := coalesce(p_payload->>'source', 'osm');
  v_place_id text := p_payload->>'source_place_id';
  v_lat double precision := (p_payload->>'latitude')::double precision;
  v_lng double precision := (p_payload->>'longitude')::double precision;
begin
  if v_name is null or v_name = '' then raise exception 'name_required'; end if;

  if v_place_id is not null then
    select id into v_dup_staging from public.venue_import_staging
    where source = v_source and source_place_id = v_place_id limit 1;
    select id into v_dup_venue from public.venues
    where data_source = v_source and source_place_id = v_place_id and deleted_at is null limit 1;
  end if;

  if v_dup_staging is null and v_dup_venue is null then
    select s.id into v_dup_staging from public.venue_import_staging s
    where lower(trim(s.name)) = lower(v_name)
      and abs(s.latitude - v_lat) < 0.001
      and abs(s.longitude - v_lng) < 0.001
    limit 1;
  end if;

  insert into public.venue_import_staging (
    job_id, status, name, category_slug,
    address_line1, address_line2, city, district, state, postal_code, country,
    phone, website, latitude, longitude,
    source, source_place_id, osm_id,
    operating_hours, amenities, ratings, image_refs, raw_payload,
    duplicate_of_staging_id, duplicate_of_venue_id,
    fetched_at
  ) values (
    p_job_id,
    case when v_dup_staging is not null or v_dup_venue is not null
         then 'duplicate'::public.venue_import_staging_status
         else 'pending_review'::public.venue_import_staging_status end,
    v_name,
    p_payload->>'category_slug',
    public.normalize_venue_address(p_payload->>'address_line1'),
    p_payload->>'address_line2',
    p_payload->>'city',
    p_payload->>'district',
    p_payload->>'state',
    p_payload->>'postal_code',
    coalesce(p_payload->>'country', 'IN'),
    public.normalize_venue_phone(p_payload->>'phone'),
    p_payload->>'website',
    v_lat,
    v_lng,
    v_source,
    v_place_id,
    p_payload->>'osm_id',
    coalesce(p_payload->'operating_hours', '[]'::jsonb),
    coalesce(p_payload->'amenities', '[]'::jsonb),
    coalesce(p_payload->'ratings', '{}'::jsonb),
    coalesce(p_payload->'image_refs', '[]'::jsonb),
    p_payload,
    v_dup_staging,
    v_dup_venue,
    coalesce((p_payload->>'fetched_at')::timestamptz, now())
  ) returning * into v_staging;

  return v_staging;
end;
$$;

-- ------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------
alter table public.venue_import_category_mappings enable row level security;
alter table public.venue_import_jobs enable row level security;
alter table public.venue_import_staging enable row level security;
alter table public.venue_claims enable row level security;

create policy venue_import_mappings_admin_read on public.venue_import_category_mappings
  for select using (public.is_admin_user());

create policy venue_import_jobs_admin_all on public.venue_import_jobs
  for all using (public.is_admin_user())
  with check (public.is_admin_user());

create policy venue_import_staging_admin_all on public.venue_import_staging
  for all using (public.is_admin_user())
  with check (public.is_admin_user());

create policy venue_claims_select on public.venue_claims
  for select using (
    claimant_user_id = auth.uid()
    or public.is_admin_user()
  );

create policy venue_claims_insert on public.venue_claims
  for insert with check (claimant_user_id = auth.uid());

create policy venue_claims_admin_update on public.venue_claims
  for update using (public.is_admin_user())
  with check (public.is_admin_user());

-- ------------------------------------------------------------
-- GRANTS
-- ------------------------------------------------------------
revoke all on function public.is_admin_user(uuid) from public, anon, authenticated;
grant execute on function public.is_admin_user(uuid) to authenticated, service_role;

revoke all on function public.admin_create_venue_import_job(text, text, text, text) from public, anon;
grant execute on function public.admin_create_venue_import_job(text, text, text, text) to authenticated;

revoke all on function public.admin_review_staging_venue(uuid, boolean, text) from public, anon;
grant execute on function public.admin_review_staging_venue(uuid, boolean, text) to authenticated;

revoke all on function public.admin_publish_staged_venue(uuid) from public, anon;
grant execute on function public.admin_publish_staged_venue(uuid) to authenticated;

revoke all on function public.submit_venue_claim(uuid, jsonb) from public, anon;
grant execute on function public.submit_venue_claim(uuid, jsonb) to authenticated;

revoke all on function public.admin_review_venue_claim(uuid, boolean, text) from public, anon;
grant execute on function public.admin_review_venue_claim(uuid, boolean, text) to authenticated;

revoke all on function public.service_stage_import_venue(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.service_stage_import_venue(uuid, jsonb) to service_role;

revoke all on function public.platform_import_org_id() from public, anon, authenticated;
grant execute on function public.platform_import_org_id() to authenticated, service_role;

grant select on public.venue_import_category_mappings to authenticated;
grant select, insert, update, delete on public.venue_import_jobs to authenticated;
grant select, insert, update, delete on public.venue_import_staging to authenticated;
grant select, insert, update on public.venue_claims to authenticated;

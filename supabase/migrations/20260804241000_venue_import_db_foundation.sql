-- ============================================================
-- Venue Import DB foundation (names + provenance + owner lock)
-- Tables/views: venue_sources, import_jobs, staged_venues
-- No UI / no external fetch in this migration.
-- ============================================================

-- ------------------------------------------------------------
-- SOURCE REGISTRY
-- ------------------------------------------------------------
create table if not exists public.venue_sources (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  source_type text not null check (source_type in ('osm', 'google_places', 'manual', 'other')),
  base_url text,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

insert into public.venue_sources (id, code, name, source_type, base_url, notes) values
  ('b1000000-0000-4000-8000-000000000001', 'osm', 'OpenStreetMap / Overpass', 'osm', 'https://overpass-api.de', 'OSM ToS; rate-limit compliant'),
  ('b1000000-0000-4000-8000-000000000002', 'google_places', 'Google Places', 'google_places', 'https://maps.googleapis.com', 'Requires API key; Places ToS'),
  ('b1000000-0000-4000-8000-000000000003', 'manual', 'Manual entry', 'manual', null, 'Admin-entered staging rows')
on conflict (code) do update set
  name = excluded.name,
  source_type = excluded.source_type,
  base_url = excluded.base_url,
  notes = excluded.notes;

-- Link jobs to source registry when venue_import_jobs already exists.
do $$
begin
  if to_regclass('public.venue_import_jobs') is not null
     and not exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'venue_import_jobs'
         and column_name = 'source_id'
     ) then
    alter table public.venue_import_jobs
      add column source_id uuid references public.venue_sources(id)
      default 'b1000000-0000-4000-8000-000000000001'::uuid;

    update public.venue_import_jobs j
    set source_id = s.id
    from public.venue_sources s
    where j.source_id is null
      and s.code = coalesce(nullif(trim(j.source), ''), 'osm');
  end if;
end $$;

-- ------------------------------------------------------------
-- CANONICAL NAMES (views) — import_jobs / staged_venues
-- Prefer views over duplicate physical tables when engine tables exist.
-- ------------------------------------------------------------
do $$
begin
  if to_regclass('public.venue_import_jobs') is not null then
    execute $v$
      create or replace view public.import_jobs as
      select
        j.id,
        j.country,
        j.state,
        j.category_slug as category,
        j.source,
        j.source_id,
        j.status::text as status,
        j.venues_fetched,
        j.venues_staged,
        j.venues_duplicates,
        j.error_message,
        j.created_by,
        j.created_at,
        j.completed_at,
        s.code as source_code,
        s.name as source_name
      from public.venue_import_jobs j
      left join public.venue_sources s on s.id = j.source_id
    $v$;
  else
    create table public.import_jobs (
      id uuid primary key default gen_random_uuid(),
      country text not null,
      state text not null,
      category text not null,
      source_id uuid references public.venue_sources(id),
      status text not null default 'pending'
        check (status in ('pending', 'running', 'completed', 'failed', 'cancelled')),
      error_message text,
      created_by uuid references auth.users(id),
      created_at timestamptz not null default now(),
      completed_at timestamptz
    );
  end if;
end $$;

do $$
begin
  if to_regclass('public.venue_import_staging') is not null then
    execute $v$
      create or replace view public.staged_venues as
      select
        s.id,
        s.job_id,
        s.status::text as status,
        s.name,
        s.category_slug as category,
        s.address_line1,
        s.address_line2,
        s.city,
        s.district,
        s.state,
        s.postal_code,
        s.country,
        s.phone,
        s.website,
        s.latitude,
        s.longitude,
        s.source,
        s.source_place_id,
        s.operating_hours,
        s.amenities,
        s.ratings,
        s.image_refs,
        s.fetched_at,
        s.published_venue_id,
        s.created_at,
        s.updated_at
      from public.venue_import_staging s
    $v$;
  else
    create table public.staged_venues (
      id uuid primary key default gen_random_uuid(),
      job_id uuid not null references public.import_jobs(id) on delete cascade,
      status text not null default 'staged'
        check (status in ('staged', 'reviewed', 'approved', 'rejected', 'published')),
      name text not null,
      category text not null,
      address_line1 text,
      city text,
      district text,
      state text,
      country text not null default 'IN',
      phone text,
      website text,
      latitude double precision,
      longitude double precision,
      source_place_id text,
      source_id uuid references public.venue_sources(id),
      fetched_at timestamptz not null default now(),
      published_venue_id uuid references public.venues(id),
      created_at timestamptz not null default now()
    );
  end if;
end $$;

-- ------------------------------------------------------------
-- OWNER-VERIFIED PROTECTION
-- ------------------------------------------------------------
alter table public.venues
  add column if not exists owner_verified boolean not null default false;

-- Keep boolean in sync with owner_verified_fields when that column exists.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'venues'
      and column_name = 'owner_verified_fields'
  ) then
    update public.venues
    set owner_verified = true
    where owner_verified = false
      and jsonb_typeof(owner_verified_fields) = 'array'
      and jsonb_array_length(owner_verified_fields) > 0;
  end if;
end $$;

-- Refuse import overwrite of owner-verified venues (foundation helper).
create or replace function public.venue_import_may_overwrite(p_venue_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select not coalesce(
    (select v.owner_verified from public.venues v where v.id = p_venue_id and v.deleted_at is null),
    false
  );
$$;

create or replace function public.protect_owner_verified_venue_fields()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  -- Full content lock when owner_verified (import must not overwrite).
  if old.owner_verified is true then
    new.name := old.name;
    new.address_line1 := old.address_line1;
    new.address_line2 := old.address_line2;
    new.city := old.city;
    new.state := old.state;
    new.postal_code := old.postal_code;
    new.country := old.country;
    new.latitude := old.latitude;
    new.longitude := old.longitude;
    new.category_id := old.category_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_owner_verified_venue on public.venues;
create trigger trg_protect_owner_verified_venue
  before update on public.venues
  for each row
  execute function public.protect_owner_verified_venue_fields();

-- Tighten publish path when engine staging table already exists.
do $$
begin
  if to_regclass('public.venue_import_staging') is null
     or not exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'is_admin_user'
     ) then
    return;
  end if;

  execute $fn$
    create or replace function public.admin_publish_staged_venue(p_staging_id uuid)
    returns public.venues
    language plpgsql
    security definer
    set search_path = public, pg_temp
    as $body$
    declare
      v_staging public.venue_import_staging;
      v_venue public.venues;
      v_org uuid;
      v_category_id uuid;
      v_existing uuid;
      v_verified jsonb;
      v_owner_verified boolean;
    begin
      if not public.is_admin_user() then raise exception 'admin_required'; end if;

      select * into v_staging from public.venue_import_staging
      where id = p_staging_id and status = 'approved';
      if v_staging is null then raise exception 'staging_not_approved'; end if;

      v_org := public.platform_import_org_id();
      if v_org is null then raise exception 'platform_import_org_missing'; end if;

      select id into v_category_id from public.venue_categories
      where slug = v_staging.category_slug;

      if v_staging.source_place_id is not null then
        select id, owner_verified_fields, owner_verified
          into v_existing, v_verified, v_owner_verified
        from public.venues
        where data_source = v_staging.source
          and source_place_id = v_staging.source_place_id
          and deleted_at is null
        limit 1;
      end if;

      if v_existing is not null and coalesce(v_owner_verified, false) then
        update public.venue_import_staging
        set status = 'published',
            published_venue_id = v_existing,
            review_notes = coalesce(review_notes, '') || ' [skipped_overwrite:owner_verified]',
            updated_at = now()
        where id = p_staging_id;

        select * into v_venue from public.venues where id = v_existing;
        return v_venue;
      end if;

      if v_existing is null then
        insert into public.venues (
          org_id, category_id, name, slug,
          address_line1, address_line2, city, state, postal_code, country,
          latitude, longitude, capacity, pricing_base_amount,
          data_source, source_place_id, source_fetched_at,
          is_claimable, is_active, is_verified, import_staging_id, owner_verified
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
          100, 0,
          v_staging.source,
          v_staging.source_place_id,
          v_staging.fetched_at,
          true, true, false, v_staging.id, false
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

      update public.venue_import_staging
      set status = 'published',
          published_venue_id = v_venue.id,
          updated_at = now()
      where id = p_staging_id;

      return v_venue;
    end;
    $body$;
  $fn$;
end $$;

-- ------------------------------------------------------------
-- RLS / GRANTS for venue_sources
-- ------------------------------------------------------------
alter table public.venue_sources enable row level security;

drop policy if exists venue_sources_admin_all on public.venue_sources;
create policy venue_sources_admin_all on public.venue_sources
  for all
  using (
    public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  )
  with check (
    public.has_role((select auth.uid()), 'administrator')
    or public.has_role((select auth.uid()), 'super_administrator')
  );

drop policy if exists venue_sources_authenticated_read on public.venue_sources;
create policy venue_sources_authenticated_read on public.venue_sources
  for select using (auth.role() = 'authenticated');

grant select on public.venue_sources to authenticated;
grant select, insert, update, delete on public.venue_sources to authenticated;

grant select on public.import_jobs to authenticated;
grant select on public.staged_venues to authenticated;

-- Physical tables (when views were not created from engine migration)
do $$
begin
  if exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'import_jobs' and c.relkind = 'r'
  ) then
    execute 'alter table public.import_jobs enable row level security';
    execute $p$
      drop policy if exists import_jobs_admin_all on public.import_jobs;
      create policy import_jobs_admin_all on public.import_jobs
        for all using (
          public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        )
        with check (
          public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        );
    $p$;
    execute 'grant select, insert, update, delete on public.import_jobs to authenticated';
  end if;

  if exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'staged_venues' and c.relkind = 'r'
  ) then
    execute 'alter table public.staged_venues enable row level security';
    execute $p$
      drop policy if exists staged_venues_admin_all on public.staged_venues;
      create policy staged_venues_admin_all on public.staged_venues
        for all using (
          public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        )
        with check (
          public.has_role((select auth.uid()), 'administrator')
          or public.has_role((select auth.uid()), 'super_administrator')
        );
    $p$;
    execute 'grant select, insert, update, delete on public.staged_venues to authenticated';
  end if;
end $$;

revoke all on function public.venue_import_may_overwrite(uuid) from public, anon;
grant execute on function public.venue_import_may_overwrite(uuid) to authenticated, service_role;

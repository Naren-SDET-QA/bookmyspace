-- ============================================================
-- BookMySpace — Additive Flutter parity foundation
--
-- Does not replace Razorpay, auth, RLS security model, or
-- existing Function Hall booking behaviour.
-- Does not seed fake venues, PINs, bookings, or payments.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Dynamic category configuration (metadata on existing rows)
-- ------------------------------------------------------------
alter table public.venue_categories
  add column if not exists metadata jsonb not null default '{}'::jsonb;

comment on column public.venue_categories.metadata is
  'Category configuration: section, aliases, localized names, visibility, bookable, booking_mode, required/optional fields, filters, amenities, pricing_mode, availability_mode, customer_action, owner_fields, search/ai aliases, media_configuration, sort_order.';

create index if not exists venue_categories_metadata_gin
  on public.venue_categories using gin (metadata);

grant select on public.venue_categories to anon, authenticated;

-- ------------------------------------------------------------
-- 2. Customer home sections (database-configurable, 4 defaults)
-- ------------------------------------------------------------
create table if not exists public.app_customer_sections (
  id text primary key,
  title text not null,
  subtitle text not null default '',
  emoji text not null default '',
  image_url text,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  is_bookable boolean not null default true,
  localized_titles jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.app_customer_sections enable row level security;

drop policy if exists app_customer_sections_public_read on public.app_customer_sections;
create policy app_customer_sections_public_read
  on public.app_customer_sections for select
  using (true);

drop policy if exists app_customer_sections_admin_write on public.app_customer_sections;
create policy app_customer_sections_admin_write
  on public.app_customer_sections for all
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

insert into public.app_customer_sections
  (id, title, subtitle, emoji, sort_order, is_visible, is_bookable)
values
  ('function_halls', 'Function Halls', 'Marriage, Convention, Party, Community & Govt Halls', '🏛️', 10, true, true),
  ('lodge_rooms', 'Lodge / Rooms', 'Hotels, Lodges, Guest Houses & Day Rooms', '🏨', 20, true, true),
  ('pg_hostels', 'PG / Hostels', 'Gents PG, Ladies PG, Hostels & Co-living', '🏠', 30, true, true),
  ('institutes_classes', 'Institutes / Classes', 'Coaching, Tuition, Computer, Dance, Music & Sports', '🎓', 40, true, false)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 3. Media kind on venue images (images now; video/3D later)
-- ------------------------------------------------------------
alter table public.venue_images
  add column if not exists media_kind text not null default 'image';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'venue_images_media_kind_check'
  ) then
    alter table public.venue_images
      add constraint venue_images_media_kind_check
      check (media_kind in ('image', 'video', 'model_3d', 'other'));
  end if;
end $$;

-- ------------------------------------------------------------
-- 4. Listing lifecycle (server-authoritative)
--    DRAFT → PENDING_APPROVAL → APPROVED/REJECTED → PUBLISHED
-- ------------------------------------------------------------
alter table public.venues
  add column if not exists listing_status text not null default 'draft';

alter table public.venues
  add column if not exists listing_rejection_reason text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'venues_listing_status_check'
  ) then
    alter table public.venues
      add constraint venues_listing_status_check
      check (listing_status in (
        'draft', 'pending_approval', 'approved', 'rejected', 'published'
      ));
  end if;
end $$;

update public.venues
set listing_status = case
  when deleted_at is not null then 'draft'
  when is_active and is_verified then 'published'
  when is_active then 'pending_approval'
  else 'draft'
end
where listing_status = 'draft';

-- ------------------------------------------------------------
-- 5. Institute profile extras, faculty, gallery, demo flag
-- ------------------------------------------------------------
alter table public.institutes
  add column if not exists phone text,
  add column if not exists whatsapp text,
  add column if not exists website_url text,
  add column if not exists instagram_url text,
  add column if not exists address text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists postal_code text,
  add column if not exists country text not null default 'IN',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists is_published boolean not null default true;

alter table public.courses
  add column if not exists is_demo boolean not null default false,
  add column if not exists seats integer,
  add column if not exists schedule_notes text;

create table if not exists public.institute_faculty (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references public.institutes(id) on delete cascade,
  name text not null,
  qualification text,
  experience_years integer not null default 0,
  specialization text,
  photo_url text,
  bio text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.institute_media (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references public.institutes(id) on delete cascade,
  url text not null,
  thumbnail_url text,
  alt_text text,
  media_kind text not null default 'image'
    check (media_kind in ('image', 'video', 'model_3d', 'other')),
  is_cover boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.institute_faculty enable row level security;
alter table public.institute_media enable row level security;

drop policy if exists institute_faculty_public_read on public.institute_faculty;
create policy institute_faculty_public_read
  on public.institute_faculty for select using (true);

drop policy if exists institute_faculty_owner_write on public.institute_faculty;
create policy institute_faculty_owner_write
  on public.institute_faculty for all
  using (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  );

drop policy if exists institute_media_public_read on public.institute_media;
create policy institute_media_public_read
  on public.institute_media for select using (true);

drop policy if exists institute_media_owner_write on public.institute_media;
create policy institute_media_owner_write
  on public.institute_media for all
  using (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- 6. QR / booking check-in (owner or admin; never fabricates bookings)
-- ------------------------------------------------------------
create table if not exists public.booking_check_ins (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  checked_in_by uuid not null references auth.users(id),
  method text not null default 'code'
    check (method in ('qr', 'code', 'manual')),
  created_at timestamptz not null default now()
);

create unique index if not exists booking_check_ins_one_per_booking
  on public.booking_check_ins (booking_id);

alter table public.booking_check_ins enable row level security;

drop policy if exists booking_check_ins_owner_read on public.booking_check_ins;
create policy booking_check_ins_owner_read
  on public.booking_check_ins for select
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
    or exists (
      select 1 from public.bookings b
      join public.venues v on v.id = b.venue_id
      join public.organizations o on o.id = v.org_id
      where b.id = booking_id
        and (o.owner_user_id = auth.uid() or b.user_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- 7. Admin read policies (oversight; does not bypass booking authority)
-- ------------------------------------------------------------
drop policy if exists bookings_admin_read on public.bookings;
create policy bookings_admin_read
  on public.bookings for select
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

drop policy if exists payments_admin_read on public.payments;
create policy payments_admin_read
  on public.payments for select
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

drop policy if exists refunds_admin_read on public.refunds;
create policy refunds_admin_read
  on public.refunds for select
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

drop policy if exists venues_admin_read on public.venues;
create policy venues_admin_read
  on public.venues for select
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

-- ------------------------------------------------------------
-- 8. Seed category metadata + extra configurable categories
--    (no venues, bookings, or geography invented)
-- ------------------------------------------------------------
update public.venue_categories set metadata = jsonb_build_object(
  'section', 'function_halls',
  'active', true,
  'bookable', true,
  'booking_mode', 'instant',
  'customer_action_label', 'Book Now',
  'pricing_mode', 'slot',
  'availability_mode', 'slots',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name)
)
where slug in (
  'function_hall', 'marriage_hall', 'convention_center', 'party_hall',
  'meeting_room', 'community_hall', 'auditorium', 'banquet_hall',
  'govt_hall', 'party_lawn'
)
and metadata = '{}'::jsonb;

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'lodge_rooms',
  'active', true,
  'bookable', true,
  'booking_mode', 'instant',
  'customer_action_label', 'Book Stay',
  'pricing_mode', 'nightly',
  'availability_mode', 'date_range',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name)
)
where slug in (
  'hotel_stay', 'hotel', 'lodge', 'guest_house', 'hourly_room', 'resort', 'homestay'
)
and metadata = '{}'::jsonb;

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'pg_hostels',
  'active', true,
  'bookable', true,
  'booking_mode', 'instant',
  'customer_action_label', 'Reserve',
  'pricing_mode', 'monthly',
  'availability_mode', 'move_in',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name)
)
where slug in (
  'pg_coliving', 'pg_hostel', 'hostel', 'co_living', 'gents_pg',
  'ladies_pg', 'student_hostel'
)
and metadata = '{}'::jsonb;

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'institutes_classes',
  'active', true,
  'bookable', false,
  'booking_mode', 'listing_only',
  'customer_action_label', 'Enquire',
  'pricing_mode', 'course_fee',
  'availability_mode', 'batches',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name)
)
where slug in (
  'institute', 'coaching', 'computer_it', 'dance_academy',
  'music_class', 'sports_academy', 'sports_ground'
)
and metadata = '{}'::jsonb;

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'function_halls',
  'active', true,
  'bookable', true,
  'booking_mode', 'instant',
  'customer_action_label', 'Book Now',
  'pricing_mode', 'slot',
  'availability_mode', 'slots',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug, 'coworking', 'co-working']),
  'search_aliases', to_jsonb(array[name, slug, 'coworking']),
  'ai_aliases', to_jsonb(array[name, slug, 'coworking']),
  'localized_names', jsonb_build_object('en', name)
)
where slug = 'coworking_space'
and metadata = '{}'::jsonb;

insert into public.venue_categories (slug, name, icon, metadata) values
  (
    'temple',
    'Temple',
    'temple_hindu',
    jsonb_build_object(
      'section', 'function_halls',
      'active', true,
      'bookable', true,
      'booking_mode', 'owner_approval',
      'customer_action_label', 'Request Slot',
      'pricing_mode', 'slot',
      'availability_mode', 'slots',
      'media_configuration', 'images',
      'aliases', '["temple","mandir","devasthanam"]'::jsonb,
      'search_aliases', '["temple","mandir"]'::jsonb,
      'ai_aliases', '["temple","mandir"]'::jsonb,
      'localized_names', '{"en":"Temple","te":"గుడి","hi":"मंदिर"}'::jsonb
    )
  ),
  (
    'exhibition_hall',
    'Exhibition Hall',
    'museum',
    jsonb_build_object(
      'section', 'function_halls',
      'active', true,
      'bookable', true,
      'booking_mode', 'instant',
      'customer_action_label', 'Book Now',
      'pricing_mode', 'slot',
      'availability_mode', 'slots',
      'media_configuration', 'images',
      'aliases', '["exhibition","expo","trade show"]'::jsonb,
      'search_aliases', '["exhibition","expo"]'::jsonb,
      'ai_aliases', '["exhibition","expo"]'::jsonb,
      'localized_names', '{"en":"Exhibition Hall"}'::jsonb
    )
  )
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- 9. RPCs — listing lifecycle, category metadata, check-in
-- ------------------------------------------------------------
create or replace function public.submit_listing_for_review(p_venue_id uuid)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue public.venues;
begin
  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid()
    and v.deleted_at is null;

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set
    listing_status = 'pending_approval',
    listing_rejection_reason = null,
    is_active = false,
    updated_at = now()
  where id = p_venue_id
  returning * into v_venue;

  begin
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'listing.submit_for_review',
      'venue',
      p_venue_id,
      jsonb_build_object('status', 'pending_approval')
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return v_venue;
end;
$$;

create or replace function public.admin_moderate_listing(
  p_venue_id uuid,
  p_action text,
  p_reason text default null
)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue public.venues;
  v_status text;
  v_active boolean;
  v_verified boolean;
begin
  if not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  if p_action not in ('approve', 'reject', 'publish', 'unpublish') then
    raise exception 'invalid_moderation_action';
  end if;

  select * into v_venue from public.venues where id = p_venue_id;
  if v_venue is null then
    raise exception 'venue_not_found';
  end if;

  if p_action = 'approve' then
    v_status := 'approved';
    v_active := false;
    v_verified := true;
  elsif p_action = 'publish' then
    v_status := 'published';
    v_active := true;
    v_verified := true;
  elsif p_action = 'unpublish' then
    v_status := 'approved';
    v_active := false;
    v_verified := v_venue.is_verified;
  else
    if p_reason is null or length(trim(p_reason)) = 0 then
      raise exception 'rejection_reason_required';
    end if;
    v_status := 'rejected';
    v_active := false;
    v_verified := false;
  end if;

  update public.venues
  set
    listing_status = v_status,
    listing_rejection_reason = case when p_action = 'reject' then p_reason else null end,
    is_active = v_active,
    is_verified = v_verified,
    updated_at = now()
  where id = p_venue_id
  returning * into v_venue;

  begin
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'listing.' || p_action,
      'venue',
      p_venue_id,
      jsonb_build_object('status', v_status, 'reason', p_reason)
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return v_venue;
end;
$$;

create or replace function public.admin_list_listings(p_status text default null)
returns setof public.venues
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  return query
  select v.*
  from public.venues v
  where v.deleted_at is null
    and (p_status is null or p_status = '' or v.listing_status = p_status)
  order by v.updated_at desc;
end;
$$;

create or replace function public.admin_update_category_metadata(
  p_category_id uuid,
  p_metadata jsonb
)
returns public.venue_categories
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.venue_categories;
begin
  if not (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  ) then
    raise exception 'not_authorized';
  end if;

  update public.venue_categories
  set metadata = coalesce(p_metadata, '{}'::jsonb)
  where id = p_category_id
  returning * into v_row;

  if v_row is null then
    raise exception 'category_not_found';
  end if;

  begin
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'category.update_metadata',
      'venue_category',
      p_category_id,
      jsonb_build_object('slug', v_row.slug)
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return v_row;
end;
$$;

create or replace function public.check_in_booking(
  p_code text,
  p_method text default 'code'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings;
  v_existing uuid;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if p_method not in ('qr', 'code', 'manual') then
    raise exception 'invalid_check_in_method';
  end if;

  select b.* into v_booking
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where (
    b.id::text = p_code
    or b.id::text like p_code || '%'
  )
    and (
      o.owner_user_id = auth.uid()
      or public.has_role(auth.uid(), 'administrator')
      or public.has_role(auth.uid(), 'super_administrator')
    )
  order by b.created_at desc
  limit 1;

  if v_booking is null then
    raise exception 'booking_not_found_or_not_owner';
  end if;

  if v_booking.status not in ('confirmed', 'completed') then
    raise exception 'booking_not_eligible_for_check_in';
  end if;

  select id into v_existing
  from public.booking_check_ins
  where booking_id = v_booking.id;

  if v_existing is not null then
    return jsonb_build_object(
      'ok', true,
      'already_checked_in', true,
      'booking_id', v_booking.id,
      'check_in_id', v_existing
    );
  end if;

  insert into public.booking_check_ins (booking_id, checked_in_by, method)
  values (v_booking.id, auth.uid(), p_method)
  returning id into v_id;

  begin
    insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
    values (
      auth.uid(),
      'booking.check_in',
      'booking',
      v_booking.id,
      jsonb_build_object('method', p_method)
    );
  exception when undefined_column or undefined_table then
    null;
  end;

  return jsonb_build_object(
    'ok', true,
    'already_checked_in', false,
    'booking_id', v_booking.id,
    'check_in_id', v_id
  );
end;
$$;

grant execute on function public.submit_listing_for_review(uuid) to authenticated;
grant execute on function public.admin_moderate_listing(uuid, text, text) to authenticated;
grant execute on function public.admin_list_listings(text) to authenticated;
grant execute on function public.admin_update_category_metadata(uuid, jsonb) to authenticated;
grant execute on function public.check_in_booking(text, text) to authenticated;

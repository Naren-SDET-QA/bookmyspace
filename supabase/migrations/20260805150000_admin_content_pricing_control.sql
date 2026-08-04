-- ============================================================
-- Admin Content & Pricing Control
-- DB-backed homepage/category/offer config + admin venue content
-- RPCs with owner_verified guards and audit logging.
-- ============================================================

-- ------------------------------------------------------------
-- VENUES: contact / featured / offers
-- ------------------------------------------------------------
alter table public.venues
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists is_featured boolean not null default false,
  add column if not exists offer_text text,
  add column if not exists offer_percent numeric(5,2)
    check (offer_percent is null or (offer_percent >= 0 and offer_percent <= 100));

create index if not exists idx_venues_featured
  on public.venues(is_featured, avg_rating desc)
  where deleted_at is null and is_active and is_featured;

-- ------------------------------------------------------------
-- CATEGORIES: display / home visibility
-- ------------------------------------------------------------
alter table public.venue_categories
  add column if not exists display_name text,
  add column if not exists sort_order integer not null default 100,
  add column if not exists is_home_visible boolean not null default true;

update public.venue_categories vc
set
  icon = coalesce(nullif(vc.icon, ''), emoji_seed.emoji),
  display_name = coalesce(vc.display_name, vc.name),
  sort_order = emoji_seed.sort_order
from (values
  ('function_hall', '🏛️', 10),
  ('marriage_hall', '💍', 20),
  ('convention_center', '🏨', 30),
  ('party_hall', '🎉', 40),
  ('meeting_room', '🤝', 50),
  ('community_hall', '🏛️', 60),
  ('sports_ground', '🏆', 70),
  ('coworking_space', '💻', 80),
  ('auditorium', '🎭', 90),
  ('hotel', '🛏️', 100),
  ('resort', '🌴', 110),
  ('institute', '🎓', 120),
  ('classroom', '📚', 130),
  ('event_space', '🎪', 140)
) as emoji_seed(slug, emoji, sort_order)
where vc.slug = emoji_seed.slug;

-- ------------------------------------------------------------
-- HOMEPAGE SECTIONS
-- ------------------------------------------------------------
create table if not exists public.homepage_sections (
  id uuid primary key default gen_random_uuid(),
  section_key text unique not null,
  title text not null,
  emoji text,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.homepage_sections enable row level security;

drop policy if exists homepage_sections_public_read on public.homepage_sections;
create policy homepage_sections_public_read on public.homepage_sections
  for select using (true);

drop policy if exists homepage_sections_admin_write on public.homepage_sections;
create policy homepage_sections_admin_write on public.homepage_sections
  for all to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

grant select on public.homepage_sections to anon, authenticated;
grant insert, update, delete on public.homepage_sections to authenticated;

insert into public.homepage_sections (section_key, title, emoji, sort_order, is_visible, config)
values
  ('categories', 'Browse categories', '🗂️', 10, true, '{}'::jsonb),
  ('events', 'Happening near you', '⚡', 20, true, '{}'::jsonb),
  ('courses', 'Popular institutes', '🎓', 30, true, '{}'::jsonb),
  ('featured', 'Featured venues', '⭐', 40, true, '{"limit": 6}'::jsonb),
  ('popular', 'Popular venues', '🏛️', 50, true, '{"limit": 10}'::jsonb),
  ('nearby', 'Nearby venues', '📍', 60, true, '{}'::jsonb)
on conflict (section_key) do nothing;

-- ------------------------------------------------------------
-- HOME CATEGORY TILES (customer home grid — remote config)
-- ------------------------------------------------------------
create table if not exists public.home_category_tiles (
  id uuid primary key default gen_random_uuid(),
  tile_key text unique not null,
  label text not null,
  emoji text not null default '📌',
  route_target text not null,
  sort_order integer not null default 0,
  is_visible boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.home_category_tiles enable row level security;

drop policy if exists home_category_tiles_public_read on public.home_category_tiles;
create policy home_category_tiles_public_read on public.home_category_tiles
  for select using (true);

drop policy if exists home_category_tiles_admin_write on public.home_category_tiles;
create policy home_category_tiles_admin_write on public.home_category_tiles
  for all to authenticated
  using (public.is_admin_user())
  with check (public.is_admin_user());

grant select on public.home_category_tiles to anon, authenticated;
grant insert, update, delete on public.home_category_tiles to authenticated;

insert into public.home_category_tiles (tile_key, label, emoji, route_target, sort_order, is_visible)
values
  ('function_hall', 'Function Halls', '🏛️', 'search:function_hall', 10, true),
  ('classes', 'Classes', '🎓', 'courses', 20, true),
  ('events', 'Events', '📅', 'events', 30, true),
  ('meeting_room', 'Meetings', '🤝', 'meeting_rooms', 40, true),
  ('conferences', 'Conferences', '🎤', 'events', 50, true),
  ('parties', 'Parties', '🎉', 'events', 60, true),
  ('sports_ground', 'Sports', '🏆', 'sports', 70, true),
  ('shows', 'Shows', '🎭', 'events', 80, true)
on conflict (tile_key) do nothing;

-- ------------------------------------------------------------
-- PLATFORM SETTINGS seeds (offers / commission defaults)
-- ------------------------------------------------------------
insert into public.platform_settings (key, value, description)
values
  (
    'default_commission_rate',
    '{"rate": 10.00}'::jsonb,
    'Default platform commission percent for new organizations'
  ),
  (
    'home_banner',
    '{"title":"Book spaces near you","subtitle":"Halls, classes, sports & more","image_url":"","cta_label":"Explore","cta_route":"/search","is_visible":true}'::jsonb,
    'Customer home banner / promo strip'
  ),
  (
    'featured_offer',
    '{"title":"Featured listing","body":"Promote venues from ₹999/mo","is_visible":true}'::jsonb,
    'Featured / promo offer copy shown in admin preview and marketing surfaces'
  )
on conflict (key) do nothing;

-- Public read for customer-facing settings keys only.
drop policy if exists platform_settings_public_read_keys on public.platform_settings;
create policy platform_settings_public_read_keys on public.platform_settings
  for select
  using (
    key in ('home_banner', 'featured_offer', 'default_commission_rate')
    or public.is_admin_user()
  );

grant select on public.platform_settings to anon;

-- ------------------------------------------------------------
-- AUDIT HELPER
-- ------------------------------------------------------------
create or replace function public.write_admin_content_audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(),
    p_action,
    p_entity_type,
    p_entity_id,
    coalesce(p_details, '{}'::jsonb)
  );
exception
  when others then
    if sqlstate = '42501' then raise; end if;
end;
$$;

revoke all on function public.write_admin_content_audit(text, text, uuid, jsonb) from public, anon;
grant execute on function public.write_admin_content_audit(text, text, uuid, jsonb)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- OWNER-VERIFIED FIELD GUARD (shared)
-- ------------------------------------------------------------
create or replace function public.admin_content_field_locked(
  p_venue public.venues,
  p_field text
)
returns boolean
language sql
stable
as $$
  select
    coalesce(p_venue.owner_verified, false)
    or (
      jsonb_typeof(coalesce(p_venue.owner_verified_fields, '[]'::jsonb)) = 'array'
      and coalesce(p_venue.owner_verified_fields, '[]'::jsonb) ? p_field
    );
$$;

-- ------------------------------------------------------------
-- PUBLIC: homepage config for customer app (no redeploy)
-- ------------------------------------------------------------
create or replace function public.get_homepage_content_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_sections jsonb;
  v_tiles jsonb;
  v_categories jsonb;
  v_banner jsonb;
  v_offer jsonb;
  v_commission jsonb;
begin
  select coalesce(jsonb_agg(to_jsonb(s) order by s.sort_order, s.section_key), '[]'::jsonb)
    into v_sections
  from public.homepage_sections s
  where s.is_visible;

  select coalesce(jsonb_agg(to_jsonb(t) order by t.sort_order, t.tile_key), '[]'::jsonb)
    into v_tiles
  from public.home_category_tiles t
  where t.is_visible;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order, c.name), '[]'::jsonb)
    into v_categories
  from public.venue_categories c
  where c.is_home_visible;

  select value into v_banner from public.platform_settings where key = 'home_banner';
  select value into v_offer from public.platform_settings where key = 'featured_offer';
  select value into v_commission from public.platform_settings where key = 'default_commission_rate';

  return jsonb_build_object(
    'sections', coalesce(v_sections, '[]'::jsonb),
    'category_tiles', coalesce(v_tiles, '[]'::jsonb),
    'venue_categories', coalesce(v_categories, '[]'::jsonb),
    'home_banner', coalesce(v_banner, '{}'::jsonb),
    'featured_offer', coalesce(v_offer, '{}'::jsonb),
    'default_commission_rate', coalesce(v_commission, '{"rate":10}'::jsonb)
  );
end;
$$;

revoke all on function public.get_homepage_content_config() from public;
grant execute on function public.get_homepage_content_config() to anon, authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: list venues for content editor
-- ------------------------------------------------------------
create or replace function public.admin_list_content_venues(
  p_query text default null,
  p_limit integer default 50
)
returns setof public.venues
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  return query
  select v.*
  from public.venues v
  where v.deleted_at is null
    and (
      p_query is null
      or trim(p_query) = ''
      or v.name ilike '%' || trim(p_query) || '%'
      or coalesce(v.city, '') ilike '%' || trim(p_query) || '%'
    )
  order by v.is_featured desc, v.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

revoke all on function public.admin_list_content_venues(text, integer) from public, anon;
grant execute on function public.admin_list_content_venues(text, integer) to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: update venue content / pricing (owner-verified guarded)
-- ------------------------------------------------------------
create or replace function public.admin_update_venue_content(
  p_venue_id uuid,
  p_patch jsonb
)
returns public.venues
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue public.venues;
  v_locked text[] := '{}';
  v_applied jsonb := '{}'::jsonb;
  v_price numeric;
  v_offer_pct numeric;
  v_tax numeric;
  v_lat double precision;
  v_lng double precision;
  v_cap integer;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if p_patch is null or p_patch = '{}'::jsonb then
    raise exception 'patch_required';
  end if;

  select * into v_venue from public.venues
  where id = p_venue_id and deleted_at is null;
  if v_venue is null then
    raise exception 'venue_not_found';
  end if;

  -- Pricing
  if p_patch ? 'pricing_base_amount' then
    if public.admin_content_field_locked(v_venue, 'pricing_base_amount') then
      v_locked := array_append(v_locked, 'pricing_base_amount');
    else
      v_price := (p_patch->>'pricing_base_amount')::numeric;
      if v_price is null or v_price < 0 then
        raise exception 'invalid_pricing_base_amount';
      end if;
      v_venue.pricing_base_amount := v_price;
      v_applied := v_applied || jsonb_build_object('pricing_base_amount', v_price);
    end if;
  end if;

  if p_patch ? 'tax_rate' then
    v_tax := (p_patch->>'tax_rate')::numeric;
    if v_tax is null or v_tax < 0 or v_tax > 100 then
      raise exception 'invalid_tax_rate';
    end if;
    v_venue.tax_rate := v_tax;
    v_applied := v_applied || jsonb_build_object('tax_rate', v_tax);
  end if;

  -- Text / description
  if p_patch ? 'description' then
    if public.admin_content_field_locked(v_venue, 'description') then
      v_locked := array_append(v_locked, 'description');
    else
      v_venue.description := nullif(trim(p_patch->>'description'), '');
      v_applied := v_applied || jsonb_build_object('description', v_venue.description);
    end if;
  end if;

  if p_patch ? 'name' then
    if public.admin_content_field_locked(v_venue, 'name') then
      v_locked := array_append(v_locked, 'name');
    else
      if nullif(trim(p_patch->>'name'), '') is null then
        raise exception 'invalid_name';
      end if;
      v_venue.name := trim(p_patch->>'name');
      v_applied := v_applied || jsonb_build_object('name', v_venue.name);
    end if;
  end if;

  if p_patch ? 'rules' then
    v_venue.rules := nullif(trim(p_patch->>'rules'), '');
    v_applied := v_applied || jsonb_build_object('rules', v_venue.rules);
  end if;

  if p_patch ? 'food_options' then
    v_venue.food_options := nullif(trim(p_patch->>'food_options'), '');
    v_applied := v_applied || jsonb_build_object('food_options', v_venue.food_options);
  end if;

  -- Contact / map
  if p_patch ? 'phone' then
    if public.admin_content_field_locked(v_venue, 'phone') then
      v_locked := array_append(v_locked, 'phone');
    else
      v_venue.phone := public.normalize_venue_phone(p_patch->>'phone');
      v_applied := v_applied || jsonb_build_object('phone', v_venue.phone);
    end if;
  end if;

  if p_patch ? 'website' then
    if public.admin_content_field_locked(v_venue, 'website') then
      v_locked := array_append(v_locked, 'website');
    else
      v_venue.website := nullif(trim(p_patch->>'website'), '');
      v_applied := v_applied || jsonb_build_object('website', v_venue.website);
    end if;
  end if;

  if p_patch ? 'address_line1' then
    if public.admin_content_field_locked(v_venue, 'address_line1') then
      v_locked := array_append(v_locked, 'address_line1');
    else
      v_venue.address_line1 := nullif(trim(p_patch->>'address_line1'), '');
      v_applied := v_applied || jsonb_build_object('address_line1', v_venue.address_line1);
    end if;
  end if;

  if p_patch ? 'city' then
    if public.admin_content_field_locked(v_venue, 'city') then
      v_locked := array_append(v_locked, 'city');
    else
      v_venue.city := nullif(trim(p_patch->>'city'), '');
      v_applied := v_applied || jsonb_build_object('city', v_venue.city);
    end if;
  end if;

  if p_patch ? 'state' then
    if public.admin_content_field_locked(v_venue, 'state') then
      v_locked := array_append(v_locked, 'state');
    else
      v_venue.state := nullif(trim(p_patch->>'state'), '');
      v_applied := v_applied || jsonb_build_object('state', v_venue.state);
    end if;
  end if;

  if p_patch ? 'postal_code' then
    if public.admin_content_field_locked(v_venue, 'postal_code') then
      v_locked := array_append(v_locked, 'postal_code');
    else
      v_venue.postal_code := nullif(trim(p_patch->>'postal_code'), '');
      v_applied := v_applied || jsonb_build_object('postal_code', v_venue.postal_code);
    end if;
  end if;

  if p_patch ? 'latitude' or p_patch ? 'longitude' then
    if public.admin_content_field_locked(v_venue, 'latitude')
       or public.admin_content_field_locked(v_venue, 'longitude') then
      v_locked := array_append(v_locked, 'coordinates');
    else
      v_lat := coalesce((p_patch->>'latitude')::double precision, v_venue.latitude);
      v_lng := coalesce((p_patch->>'longitude')::double precision, v_venue.longitude);
      if v_lat < -90 or v_lat > 90 or v_lng < -180 or v_lng > 180 then
        raise exception 'invalid_coordinates';
      end if;
      v_venue.latitude := v_lat;
      v_venue.longitude := v_lng;
      v_applied := v_applied || jsonb_build_object('latitude', v_lat, 'longitude', v_lng);
    end if;
  end if;

  if p_patch ? 'capacity' then
    if public.admin_content_field_locked(v_venue, 'capacity') then
      v_locked := array_append(v_locked, 'capacity');
    else
      v_cap := (p_patch->>'capacity')::integer;
      if v_cap is null or v_cap <= 0 then
        raise exception 'invalid_capacity';
      end if;
      v_venue.capacity := v_cap;
      v_applied := v_applied || jsonb_build_object('capacity', v_cap);
    end if;
  end if;

  -- Platform controls (always allowed)
  if p_patch ? 'is_featured' then
    v_venue.is_featured := coalesce((p_patch->>'is_featured')::boolean, false);
    v_applied := v_applied || jsonb_build_object('is_featured', v_venue.is_featured);
  end if;

  if p_patch ? 'is_active' then
    v_venue.is_active := coalesce((p_patch->>'is_active')::boolean, true);
    v_applied := v_applied || jsonb_build_object('is_active', v_venue.is_active);
  end if;

  if p_patch ? 'offer_text' then
    v_venue.offer_text := nullif(trim(p_patch->>'offer_text'), '');
    v_applied := v_applied || jsonb_build_object('offer_text', v_venue.offer_text);
  end if;

  if p_patch ? 'offer_percent' then
    if p_patch->>'offer_percent' is null or trim(p_patch->>'offer_percent') = '' then
      v_venue.offer_percent := null;
    else
      v_offer_pct := (p_patch->>'offer_percent')::numeric;
      if v_offer_pct < 0 or v_offer_pct > 100 then
        raise exception 'invalid_offer_percent';
      end if;
      v_venue.offer_percent := v_offer_pct;
    end if;
    v_applied := v_applied || jsonb_build_object('offer_percent', v_venue.offer_percent);
  end if;

  if v_applied = '{}'::jsonb and array_length(v_locked, 1) is not null then
    raise exception 'owner_verified_locked:%', array_to_string(v_locked, ',');
  end if;

  update public.venues v
  set
    name = v_venue.name,
    description = v_venue.description,
    pricing_base_amount = v_venue.pricing_base_amount,
    tax_rate = v_venue.tax_rate,
    rules = v_venue.rules,
    food_options = v_venue.food_options,
    phone = v_venue.phone,
    website = v_venue.website,
    address_line1 = v_venue.address_line1,
    city = v_venue.city,
    state = v_venue.state,
    postal_code = v_venue.postal_code,
    latitude = v_venue.latitude,
    longitude = v_venue.longitude,
    capacity = v_venue.capacity,
    is_featured = v_venue.is_featured,
    is_active = v_venue.is_active,
    offer_text = v_venue.offer_text,
    offer_percent = v_venue.offer_percent,
    updated_at = now()
  where v.id = p_venue_id
  returning v.* into v_venue;

  perform public.write_admin_content_audit(
    'admin_update_venue_content',
    'venue',
    p_venue_id,
    jsonb_build_object(
      'applied', v_applied,
      'locked', to_jsonb(v_locked),
      'owner_verified', coalesce(v_venue.owner_verified, false)
    )
  );

  return v_venue;
end;
$$;

revoke all on function public.admin_update_venue_content(uuid, jsonb) from public, anon;
grant execute on function public.admin_update_venue_content(uuid, jsonb)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: replace venue images (banner/gallery)
-- ------------------------------------------------------------
create or replace function public.admin_replace_venue_images(
  p_venue_id uuid,
  p_images jsonb
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
  v_elem jsonb;
  v_idx integer := 0;
  v_url text;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if not exists (select 1 from public.venues where id = p_venue_id and deleted_at is null) then
    raise exception 'venue_not_found';
  end if;
  if p_images is null or jsonb_typeof(p_images) <> 'array' then
    raise exception 'images_array_required';
  end if;

  delete from public.venue_images where venue_id = p_venue_id;

  for v_elem in select * from jsonb_array_elements(p_images)
  loop
    v_url := nullif(trim(v_elem->>'url'), '');
    if v_url is null then
      raise exception 'invalid_image_url';
    end if;
    if v_url !~* '^https?://' then
      raise exception 'invalid_image_url_scheme';
    end if;
    insert into public.venue_images (
      venue_id, url, thumbnail_url, alt_text, is_cover, sort_order
    ) values (
      p_venue_id,
      v_url,
      nullif(trim(v_elem->>'thumbnail_url'), ''),
      nullif(trim(v_elem->>'alt_text'), ''),
      coalesce((v_elem->>'is_cover')::boolean, v_idx = 0),
      coalesce((v_elem->>'sort_order')::integer, v_idx)
    );
    v_idx := v_idx + 1;
    v_count := v_count + 1;
  end loop;

  perform public.write_admin_content_audit(
    'admin_replace_venue_images',
    'venue',
    p_venue_id,
    jsonb_build_object('image_count', v_count)
  );

  return v_count;
end;
$$;

revoke all on function public.admin_replace_venue_images(uuid, jsonb) from public, anon;
grant execute on function public.admin_replace_venue_images(uuid, jsonb)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: set amenities (venue_facilities)
-- ------------------------------------------------------------
create or replace function public.admin_set_venue_amenities(
  p_venue_id uuid,
  p_amenities text[]
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item text;
  v_count integer := 0;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if not exists (select 1 from public.venues where id = p_venue_id and deleted_at is null) then
    raise exception 'venue_not_found';
  end if;

  delete from public.venue_facilities where venue_id = p_venue_id;

  if p_amenities is not null then
    foreach v_item in array p_amenities
    loop
      if nullif(trim(v_item), '') is null then
        continue;
      end if;
      insert into public.venue_facilities (venue_id, facility, is_available)
      values (p_venue_id, trim(v_item), true)
      on conflict (venue_id, facility) do update set is_available = true;
      v_count := v_count + 1;
    end loop;
  end if;

  perform public.write_admin_content_audit(
    'admin_set_venue_amenities',
    'venue',
    p_venue_id,
    jsonb_build_object('amenities', to_jsonb(coalesce(p_amenities, '{}'::text[])), 'count', v_count)
  );

  return v_count;
end;
$$;

revoke all on function public.admin_set_venue_amenities(uuid, text[]) from public, anon;
grant execute on function public.admin_set_venue_amenities(uuid, text[])
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: homepage section upsert / reorder
-- ------------------------------------------------------------
create or replace function public.admin_upsert_homepage_section(
  p_section_key text,
  p_title text,
  p_emoji text default null,
  p_sort_order integer default null,
  p_is_visible boolean default null,
  p_config jsonb default null
)
returns public.homepage_sections
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.homepage_sections;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if nullif(trim(p_section_key), '') is null then
    raise exception 'section_key_required';
  end if;
  if nullif(trim(p_title), '') is null then
    raise exception 'title_required';
  end if;

  insert into public.homepage_sections as hs (
    section_key, title, emoji, sort_order, is_visible, config, updated_by, updated_at
  ) values (
    trim(p_section_key),
    trim(p_title),
    nullif(trim(coalesce(p_emoji, '')), ''),
    coalesce(p_sort_order, 100),
    coalesce(p_is_visible, true),
    coalesce(p_config, '{}'::jsonb),
    auth.uid(),
    now()
  )
  on conflict (section_key) do update set
    title = excluded.title,
    emoji = coalesce(excluded.emoji, hs.emoji),
    sort_order = coalesce(p_sort_order, hs.sort_order),
    is_visible = coalesce(p_is_visible, hs.is_visible),
    config = coalesce(p_config, hs.config),
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_row;

  perform public.write_admin_content_audit(
    'admin_upsert_homepage_section',
    'homepage_section',
    v_row.id,
    jsonb_build_object('section_key', v_row.section_key, 'is_visible', v_row.is_visible, 'sort_order', v_row.sort_order)
  );

  return v_row;
end;
$$;

revoke all on function public.admin_upsert_homepage_section(text, text, text, integer, boolean, jsonb)
  from public, anon;
grant execute on function public.admin_upsert_homepage_section(text, text, text, integer, boolean, jsonb)
  to authenticated, service_role;

create or replace function public.admin_reorder_homepage_sections(p_ordered_keys text[])
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_key text;
  v_idx integer := 0;
  v_count integer := 0;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if p_ordered_keys is null or array_length(p_ordered_keys, 1) is null then
    raise exception 'ordered_keys_required';
  end if;

  foreach v_key in array p_ordered_keys
  loop
    v_idx := v_idx + 10;
    update public.homepage_sections
    set sort_order = v_idx, updated_by = auth.uid(), updated_at = now()
    where section_key = v_key;
    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  perform public.write_admin_content_audit(
    'admin_reorder_homepage_sections',
    'homepage_section',
    null,
    jsonb_build_object('ordered_keys', to_jsonb(p_ordered_keys), 'updated', v_count)
  );

  return v_count;
end;
$$;

revoke all on function public.admin_reorder_homepage_sections(text[]) from public, anon;
grant execute on function public.admin_reorder_homepage_sections(text[])
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: category tile + venue category display
-- ------------------------------------------------------------
create or replace function public.admin_upsert_home_category_tile(
  p_tile_key text,
  p_label text,
  p_emoji text,
  p_route_target text,
  p_sort_order integer default null,
  p_is_visible boolean default null
)
returns public.home_category_tiles
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.home_category_tiles;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if nullif(trim(p_tile_key), '') is null then
    raise exception 'tile_key_required';
  end if;
  if nullif(trim(p_label), '') is null then
    raise exception 'label_required';
  end if;
  if nullif(trim(p_emoji), '') is null then
    raise exception 'emoji_required';
  end if;
  if nullif(trim(p_route_target), '') is null then
    raise exception 'route_target_required';
  end if;

  insert into public.home_category_tiles as t (
    tile_key, label, emoji, route_target, sort_order, is_visible, updated_by, updated_at
  ) values (
    trim(p_tile_key), trim(p_label), trim(p_emoji), trim(p_route_target),
    coalesce(p_sort_order, 100), coalesce(p_is_visible, true), auth.uid(), now()
  )
  on conflict (tile_key) do update set
    label = excluded.label,
    emoji = excluded.emoji,
    route_target = excluded.route_target,
    sort_order = coalesce(p_sort_order, t.sort_order),
    is_visible = coalesce(p_is_visible, t.is_visible),
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_row;

  perform public.write_admin_content_audit(
    'admin_upsert_home_category_tile',
    'home_category_tile',
    v_row.id,
    jsonb_build_object('tile_key', v_row.tile_key, 'emoji', v_row.emoji, 'is_visible', v_row.is_visible)
  );

  return v_row;
end;
$$;

revoke all on function public.admin_upsert_home_category_tile(text, text, text, text, integer, boolean)
  from public, anon;
grant execute on function public.admin_upsert_home_category_tile(text, text, text, text, integer, boolean)
  to authenticated, service_role;

create or replace function public.admin_update_category_display(
  p_category_id uuid,
  p_display_name text default null,
  p_icon text default null,
  p_sort_order integer default null,
  p_is_home_visible boolean default null
)
returns public.venue_categories
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.venue_categories;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  update public.venue_categories
  set
    display_name = coalesce(nullif(trim(p_display_name), ''), display_name, name),
    icon = coalesce(nullif(trim(p_icon), ''), icon),
    sort_order = coalesce(p_sort_order, sort_order),
    is_home_visible = coalesce(p_is_home_visible, is_home_visible)
  where id = p_category_id
  returning * into v_row;

  if v_row is null then
    raise exception 'category_not_found';
  end if;

  perform public.write_admin_content_audit(
    'admin_update_category_display',
    'venue_category',
    p_category_id,
    jsonb_build_object(
      'display_name', v_row.display_name,
      'icon', v_row.icon,
      'sort_order', v_row.sort_order,
      'is_home_visible', v_row.is_home_visible
    )
  );

  return v_row;
end;
$$;

revoke all on function public.admin_update_category_display(uuid, text, text, integer, boolean)
  from public, anon;
grant execute on function public.admin_update_category_display(uuid, text, text, integer, boolean)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: platform settings (commission / offers / banner)
-- ------------------------------------------------------------
create or replace function public.admin_set_platform_setting(
  p_key text,
  p_value jsonb,
  p_description text default null
)
returns public.platform_settings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.platform_settings;
  v_rate numeric;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if nullif(trim(p_key), '') is null then
    raise exception 'key_required';
  end if;
  if p_value is null then
    raise exception 'value_required';
  end if;

  if p_key = 'default_commission_rate' then
    v_rate := (p_value->>'rate')::numeric;
    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'invalid_commission_rate';
    end if;
  end if;

  insert into public.platform_settings as ps (key, value, description, updated_by, updated_at)
  values (trim(p_key), p_value, p_description, auth.uid(), now())
  on conflict (key) do update set
    value = excluded.value,
    description = coalesce(excluded.description, ps.description),
    updated_by = auth.uid(),
    updated_at = now()
  returning * into v_row;

  perform public.write_admin_content_audit(
    'admin_set_platform_setting',
    'platform_setting',
    null,
    jsonb_build_object('key', v_row.key, 'value', v_row.value)
  );

  return v_row;
end;
$$;

revoke all on function public.admin_set_platform_setting(text, jsonb, text) from public, anon;
grant execute on function public.admin_set_platform_setting(text, jsonb, text)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- ADMIN: org commission rate
-- ------------------------------------------------------------
create or replace function public.admin_set_org_commission(
  p_org_id uuid,
  p_commission_rate numeric
)
returns public.organizations
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.organizations;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  if p_commission_rate is null or p_commission_rate < 0 or p_commission_rate > 100 then
    raise exception 'invalid_commission_rate';
  end if;

  update public.organizations
  set commission_rate = p_commission_rate, updated_at = now()
  where id = p_org_id and deleted_at is null
  returning * into v_row;

  if v_row is null then
    raise exception 'organization_not_found';
  end if;

  perform public.write_admin_content_audit(
    'admin_set_org_commission',
    'organization',
    p_org_id,
    jsonb_build_object('commission_rate', p_commission_rate)
  );

  return v_row;
end;
$$;

revoke all on function public.admin_set_org_commission(uuid, numeric) from public, anon;
grant execute on function public.admin_set_org_commission(uuid, numeric)
  to authenticated, service_role;

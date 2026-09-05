-- BookMySpace DEV-only generic category fixture seed.
--
-- This seed creates ten deterministic sample venues for EVERY existing
-- venue_categories row. It does not create categories, Auth users, roles,
-- locations, bookings, payments, or schema objects. It only uses approved
-- existing owners and approved existing location_nodes.
--
-- Run only in the DEV SQL Editor after confirming the project ref is:
-- zykxneztahxbjduagutv
-- No DELETE/TRUNCATE/DROP is used. Re-running is safe.

begin;

do $$
declare
  v_owner uuid;
  v_org uuid;
  v_location record;
  v_category record;
  v_venue uuid;
  v_slug text;
  v_i integer;
  v_category_count integer;
  v_location_count integer;
begin
  if current_database() <> 'postgres' then
    raise exception 'REFUSED: expected Supabase postgres database';
  end if;
  if to_regclass('public.venues') is null
     or to_regclass('public.venue_categories') is null
     or to_regclass('public.location_nodes') is null
     or to_regclass('public.owner_profiles') is null
     or to_regclass('public.user_roles') is null then
    raise exception 'REFUSED: BookMySpace schema is incomplete';
  end if;

  select count(*) into v_category_count from public.venue_categories;
  select count(*) into v_location_count
  from public.location_nodes
  where status = 'active'
    and approved_at is not null
    and level in ('city_town', 'area_locality', 'village');
  if v_category_count = 0 then
    raise exception 'REFUSED: no existing venue categories found';
  end if;
  if v_location_count = 0 then
    raise exception 'REFUSED: no approved active city/area/village locations found';
  end if;

  select op.user_id into v_owner
  from public.owner_profiles op
  join public.user_roles ur on ur.user_id = op.user_id
  where ur.role in ('venue_owner', 'institute_owner', 'event_organizer')
    and ur.revoked_at is null
  order by op.user_id
  limit 1;
  if v_owner is null then
    select user_id into v_owner
    from public.owner_profiles
    order by user_id
    limit 1;
  end if;
  if v_owner is null then
    select owner_user_id into v_owner
    from public.organizations
    where owner_user_id is not null
    order by id
    limit 1;
  end if;
  if v_owner is null then
    raise exception 'REFUSED: an existing owner profile or organisation owner is required';
  end if;

  v_org := md5('bms-dev-generic:org:' || v_owner::text)::uuid;
  insert into public.organizations(
    id, owner_user_id, org_type, name, country, is_active
  ) values (
    v_org, v_owner, 'venue_owner', 'BookMySpace DEV Sample Organisation', 'IN', true
  ) on conflict (id) do update set is_active = true, updated_at = now();

  for v_category in
    select id, slug, name
    from public.venue_categories
    order by slug
  loop
    for v_i in 1..10 loop
      select ln.id,
             ln.name,
             coalesce(ln.metadata->>'postal_code', ln.metadata->>'pincode', '') as postal_code,
             coalesce(ln.latitude, 17.4483)::double precision as latitude,
             coalesce(ln.longitude, 78.3915)::double precision as longitude
      into v_location
      from public.location_nodes ln
      where ln.status = 'active'
        and ln.approved_at is not null
        and ln.level in ('city_town', 'area_locality', 'village')
      order by ln.id
      offset ((v_i - 1) % v_location_count)
      limit 1;

      v_slug := 'bms-dev-generic-' || lower(regexp_replace(v_category.slug, '[^a-z0-9]+', '-', 'g')) || '-' || lpad(v_i::text, 2, '0');
      v_venue := md5('bms-dev-generic:venue:' || v_category.slug || ':' || v_i::text)::uuid;

      insert into public.venues(
        id, org_id, category_id, name, slug, description,
        city, state, postal_code, country, location_node_id,
        latitude, longitude, capacity, pricing_base_amount,
        pricing_currency, tax_rate, is_verified, is_active,
        avg_rating, rating_count
      ) values (
        v_venue, v_org, v_category.id,
        v_category.name || ' DEV ' || v_i,
        v_slug,
        'Deterministic BookMySpace DEV sample listing for the configured category.',
        v_location.name, 'DEV', nullif(v_location.postal_code, ''), 'IN', v_location.id,
        v_location.latitude, v_location.longitude,
        20 + (v_i * 15), 750 + (v_i * 275), 'INR', 5,
        true, true, 3.5 + ((v_i % 15)::numeric / 10), 12 + v_i
      ) on conflict (id) do update set
        org_id = excluded.org_id,
        category_id = excluded.category_id,
        name = excluded.name,
        slug = excluded.slug,
        location_node_id = excluded.location_node_id,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        capacity = excluded.capacity,
        pricing_base_amount = excluded.pricing_base_amount,
        avg_rating = excluded.avg_rating,
        rating_count = excluded.rating_count,
        is_active = true;

      insert into public.venue_images(
        id, venue_id, url, thumbnail_url, alt_text, is_cover, sort_order
      )
      select
        md5(v_slug || ':image:1')::uuid,
        v_venue,
        cover_url,
        replace(cover_url, 'w=1200', 'w=600'),
        v_category.name || ' sample venue',
        true,
        1
      from (
        select case
          when v_category.slug ~* '(hotel|lodge|room|stay)' then
            'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* '(resort|home)' then
            'https://images.unsplash.com/photo-1582610116397-edb318620f90?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* '(pg|hostel|living)' then
            'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* '(institute|class|academy|coaching)' then
            'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* 'sport' then
            'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* '(event|concert)' then
            'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=1200&auto=format&fit=crop&q=82'
          when v_category.slug ~* '(hall|venue|auditorium)' then
            'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=1200&auto=format&fit=crop&q=82'
          else
            'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200&auto=format&fit=crop&q=82'
        end as cover_url
      ) img
      on conflict (id) do update set
        url = excluded.url,
        thumbnail_url = excluded.thumbnail_url,
        alt_text = excluded.alt_text;

      insert into public.venue_facilities(id, venue_id, facility, is_available)
      values
        (md5(v_slug || ':wifi')::uuid, v_venue, 'WiFi', true),
        (md5(v_slug || ':parking')::uuid, v_venue, 'Parking', true),
        (md5(v_slug || ':power')::uuid, v_venue, 'Power backup', true)
      on conflict (venue_id, facility) do update set is_available = true;

      insert into public.venue_operating_hours(
        id, venue_id, day_of_week, opens_at, closes_at, is_closed
      )
      select
        md5(v_slug || ':hours:' || d::text)::uuid, v_venue, d, '08:00', '22:00', false
      from generate_series(0, 6) as d
      on conflict (venue_id, day_of_week) do update set
        opens_at = excluded.opens_at,
        closes_at = excluded.closes_at,
        is_closed = false;

      insert into public.time_slots(
        id, venue_id, label, start_time, end_time, price_amount, is_active
      ) values
        (md5(v_slug || ':slot:1')::uuid, v_venue, 'Morning', '09:00', '13:00', 750 + (v_i * 100), true),
        (md5(v_slug || ':slot:2')::uuid, v_venue, 'Evening', '17:00', '21:00', 950 + (v_i * 100), true)
      on conflict (id) do update set
        price_amount = excluded.price_amount,
        is_active = true;
    end loop;
  end loop;
end $$;

commit;

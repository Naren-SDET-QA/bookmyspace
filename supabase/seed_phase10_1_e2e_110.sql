-- Phase 10.1 guarded DEV E2E listing seed.
-- This file never creates Auth users, roles, categories, or geography.
-- The PowerShell wrapper must validate the DEV project and pass bms_dev=1.
\if :{?bms_dev}
\else
  \echo 'REFUSED: pass -v bms_dev=1.'
  \quit 3
\endif
\if :bms_dev
\else
  \echo 'REFUSED: bms_dev must equal 1.'
  \quit 3
\endif
\if :{?bms_project_ref}
\else
  \echo 'REFUSED: pass the expected DEV project reference.'
  \quit 3
\endif

begin;

do $$
declare
  v_org uuid;
  v_owner uuid;
  v_location_count integer;
  v_categories text[] := array[
    'hotel','gents_pg','ladies_pg','pg_coliving','pg_hostel',
    'temple','function_hall','institute','computer_it','music_class',
    'sports_ground'
  ];
  v_labels text[] := array[
    'HOTEL','GENTS-PG','LADIES-PG','PG-COLIVING','PG-HOSTEL',
    'TEMPLE','FUNCTION-HALL','INSTITUTE','COMPUTER','MUSIC','SPORTS'
  ];
  v_category text;
  v_label text;
  v_category_id uuid;
  v_location uuid;
  v_venue uuid;
  v_slug text;
  v_name text;
  v_i integer;
  v_n integer;
  v_city text;
  v_state text;
  v_postal text;
begin
  select o.id, o.owner_user_id into v_org, v_owner
  from public.organizations o
  join public.owner_profiles op on op.user_id = o.owner_user_id
  where o.is_active
  order by o.created_at, o.id
  limit 1;
  if v_org is null or v_owner is null then
    raise exception 'OWNER_FIXTURE_LIMITATION: no existing active owner organization';
  end if;

  select count(*) into v_location_count
  from public.location_nodes
  where status = 'active' and approved_at is not null;
  if v_location_count < 11 then
    raise exception 'DEV seed requires at least 11 active approved locations';
  end if;

  for v_n in 1..array_length(v_categories, 1) loop
    v_category := v_categories[v_n];
    v_label := v_labels[v_n];
    select id into v_category_id from public.venue_categories where slug = v_category;
    if v_category_id is null then
      raise exception 'Missing existing category slug: %', v_category;
    end if;

    for v_i in 1..10 loop
      v_slug := 'e2e-' || lower(v_label) || '-' || lpad(v_i::text, 3, '0');
      v_name := 'E2E-' || v_label || '-' || lpad(v_i::text, 3, '0');
      select id into v_location
      from public.location_nodes
      where status = 'active' and approved_at is not null
      order by id offset ((v_n * 10 + v_i) % v_location_count) limit 1;

      select coalesce(name, 'DEV Town'), coalesce(metadata->>'state', 'Andhra Pradesh'),
             coalesce(metadata->>'postal_code', metadata->>'pincode', '000000')
      into v_city, v_state, v_postal
      from public.location_nodes where id = v_location;
      v_venue := md5('phase10.1:' || v_slug)::uuid;

      insert into public.venues (
        id, org_id, category_id, name, slug, description, address_line1,
        city, state, postal_code, country, latitude, longitude, capacity,
        pricing_base_amount, pricing_currency, tax_rate, is_verified,
        is_active, avg_rating, rating_count
      ) values (
        v_venue, v_org, v_category_id, v_name, v_slug,
        'Deterministic BookMySpace DEV E2E listing.',
        'E2E Test Address ' || v_i, v_city, v_state, v_postal, 'IN',
        15.9000 + (v_i * 0.001), 80.1000 + (v_n * 0.001),
        20 + v_i, case when v_i % 3 = 1 then 750 when v_i % 3 = 2 then 1750 else 3250 end,
        'INR', 5, true, true, 4.0, v_i
      ) on conflict (id) do update set
        org_id = excluded.org_id, category_id = excluded.category_id,
        name = excluded.name, description = excluded.description,
        city = excluded.city, state = excluded.state,
        postal_code = excluded.postal_code, location_node_id = excluded.location_node_id,
        pricing_base_amount = excluded.pricing_base_amount,
        tax_rate = excluded.tax_rate, is_active = true, deleted_at = null,
        updated_at = now();

      update public.venues set location_node_id = v_location where id = v_venue;

      insert into public.venue_images (id, venue_id, url, thumbnail_url, alt_text, is_cover, sort_order)
      values (md5('phase10.1:image:' || v_slug)::uuid, v_venue,
        'https://images.unsplash.com/photo-1519167758481-83f550bb49b3',
        'https://images.unsplash.com/photo-1519167758481-83f550bb49b3', v_name, true, 1)
      on conflict (id) do update set url = excluded.url, thumbnail_url = excluded.thumbnail_url,
        alt_text = excluded.alt_text, is_cover = true, sort_order = 1;

      insert into public.venue_facilities (id, venue_id, facility, is_available)
      values (md5('phase10.1:wifi:' || v_slug)::uuid, v_venue, 'WiFi', true),
             (md5('phase10.1:parking:' || v_slug)::uuid, v_venue, 'Parking', true)
      on conflict (venue_id, facility) do update set is_available = true;

      insert into public.venue_operating_hours (id, venue_id, day_of_week, opens_at, closes_at, is_closed)
      select md5('phase10.1:hours:' || v_slug || ':' || d)::uuid, v_venue, d, '08:00', '21:00', false
      from generate_series(0, 6) d
      on conflict (venue_id, day_of_week) do update set opens_at = '08:00', closes_at = '21:00', is_closed = false;

      insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active)
      values (md5('phase10.1:morning:' || v_slug)::uuid, v_venue, 'E2E Morning', '09:00', '13:00',
              750 + (v_i * 100), true),
             (md5('phase10.1:evening:' || v_slug)::uuid, v_venue, 'E2E Evening', '16:00', '20:00',
              1000 + (v_i * 150), true)
      on conflict (id) do update set price_amount = excluded.price_amount, is_active = true;

      insert into public.pricing_rules (id, venue_id, day_of_week, price_multiplier, note)
      values (md5('phase10.1:pricing:' || v_slug)::uuid, v_venue, null, 1.00, 'Phase 10.1 deterministic pricing')
      on conflict (id) do update set price_multiplier = 1.00, note = excluded.note;
    end loop;
  end loop;
end $$;

commit;

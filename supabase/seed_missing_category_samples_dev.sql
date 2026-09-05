-- DEV-only additive fixture for categories with no existing listing coverage.
-- Default mode is a read-only dry run. Execute with psql -v bms_apply=1.
-- This script never creates categories, users, roles, locations, bookings,
-- payments, or refunds. It reuses existing owner/org/location/media records.

begin;

do $$
declare
  apply_fixture boolean := coalesce(current_setting('bms_apply', true), '0') = '1';
  owner_id uuid;
  org_id uuid;
  location_id uuid;
  sample_url text;
  cat record;
  venue_id uuid;
  venue_slug text;
begin
  if current_database() <> 'postgres' then
    raise exception 'REFUSED: expected DEV Supabase postgres database';
  end if;
  if to_regclass('public.venues') is null
     or to_regclass('public.venue_categories') is null
     or to_regclass('public.location_nodes') is null
     or to_regclass('public.owner_profiles') is null
     or to_regclass('public.user_roles') is null
     or to_regclass('public.venue_images') is null then
    raise exception 'REFUSED: required BookMySpace schema is incomplete';
  end if;

  select op.user_id into owner_id
  from public.owner_profiles op
  join public.user_roles ur on ur.user_id = op.user_id
  where ur.role in ('venue_owner', 'institute_owner', 'event_organizer')
    and ur.revoked_at is null
  order by op.user_id limit 1;
  if owner_id is null then
    select user_id into owner_id from public.owner_profiles order by user_id limit 1;
  end if;
  if owner_id is null then
    select owner_user_id into owner_id
    from public.organizations
    where owner_user_id is not null
    order by id limit 1;
  end if;
  select o.id into org_id from public.organizations o
  where o.owner_user_id = owner_id and o.is_active order by o.id limit 1;
  select ln.id into location_id from public.location_nodes ln
  where ln.status = 'active' and ln.approved_at is not null
    and ln.level in ('city_town', 'area_locality', 'village')
  order by ln.id limit 1;
  select vi.url into sample_url from public.venue_images vi
  where vi.is_active and vi.processing_status in ('ready', 'completed')
    and nullif(vi.url, '') is not null order by vi.id limit 1;

  if owner_id is null or org_id is null or location_id is null then
    raise exception 'REFUSED: existing owner, organization, or approved location is unavailable';
  end if;

  for cat in
    select id, slug, name from public.venue_categories
    where slug in ('co_living','guest_house','homestay','hostel','hotel_stay',
      'hourly_room','lodge','resort','student_hostel','banquet_hall',
      'exhibition_hall','govt_hall','party_lawn','coaching','dance_academy',
      'sports_academy') order by slug
  loop
    venue_slug := 'bms-dev-missing-' || cat.slug;
    venue_id := md5('bms-dev-missing:' || cat.slug)::uuid;
    if exists (select 1 from public.venues where id = venue_id) then
      raise notice 'SKIP existing fixture: %', cat.slug;
    elsif not apply_fixture then
      raise notice 'DRY-RUN create: category=%, venue_slug=%, location_id=%',
        cat.slug, venue_slug, location_id;
    else
      insert into public.venues(
        id,org_id,category_id,name,slug,description,city,state,postal_code,country,
        location_node_id,latitude,longitude,capacity,pricing_base_amount,
        pricing_currency,tax_rate,is_verified,is_active
      ) values (
        venue_id,org_id,cat.id,'[DEV-SAMPLE] ' || cat.name,venue_slug,
        'Synthetic DEV sample listing for coverage validation.',
        'DEV sample location','DEV',null,'IN',location_id,17.4483,78.3915,
        20,1000,'INR',5,true,true
      );
      if sample_url is not null then
        insert into public.venue_images(id,venue_id,url,thumbnail_url,alt_text,
          is_cover,sort_order,is_active,processing_status,media_kind)
        values
          (md5(venue_slug || ':image:1')::uuid,venue_id,sample_url,sample_url,
           cat.name || ' DEV sample',true,1,true,'ready','image'),
          (md5(venue_slug || ':image:2')::uuid,venue_id,sample_url,sample_url,
           cat.name || ' DEV sample interior',false,2,true,'ready','image')
        on conflict (id) do nothing;
      else
        raise notice 'MEDIA_FIXTURE_REQUIRED: %', cat.slug;
      end if;
      insert into public.venue_operating_hours(id,venue_id,day_of_week,opens_at,closes_at,is_closed)
      values (md5(venue_slug || ':hours')::uuid,venue_id,1,'08:00','22:00',false)
      on conflict (venue_id,day_of_week) do nothing;
      insert into public.time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active)
      values
        (md5(venue_slug || ':slot:1')::uuid,venue_id,'DEV morning','09:00','13:00',1000,true),
        (md5(venue_slug || ':slot:2')::uuid,venue_id,'DEV evening','17:00','21:00',1200,true)
      on conflict (id) do nothing;
      raise notice 'CREATED: %', cat.slug;
    end if;
  end loop;
end $$;

commit;

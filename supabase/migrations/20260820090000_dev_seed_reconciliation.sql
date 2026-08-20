-- BookMySpace DEV-only seed reconciliation.
-- This file is intentionally separate from historical migrations 0001-0020.
-- It must be applied only after dev_0001_0005_foundation through
-- dev_0009_nearby_venues_rpc.

-- The existing 0001 foundation stores organizations.owner_user_id as an
-- auth.users reference.  Keep that contract; this profile table is the
-- DEV owner metadata needed by later owner migrations.
create table if not exists public.owner_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_owner_profiles_updated_at'
      and tgrelid = 'public.owner_profiles'::regclass
  ) then
    create trigger trg_owner_profiles_updated_at
      before update on public.owner_profiles
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- Deterministic DEV-only owner identity.  This is not production data.
insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000002',
  'owner@demo.com',
  jsonb_build_object('name', 'Demo Owner')
)
on conflict (id) do update
set email = excluded.email,
    raw_user_meta_data = excluded.raw_user_meta_data;

insert into public.owner_profiles (user_id, email, name)
select id, email, coalesce(raw_user_meta_data->>'name', 'Demo Owner')
from auth.users
where id = '00000000-0000-0000-0000-000000000002'
on conflict (user_id) do update
set email = excluded.email,
    name = excluded.name,
    updated_at = now();

do $$
declare
  v_owner_id uuid := '00000000-0000-0000-0000-000000000002';
  v_org_id uuid;
  v_sunrise uuid;
  v_boardroom uuid;
  v_worknest uuid;
begin
  if not exists (select 1 from public.owner_profiles where user_id = v_owner_id) then
    raise exception 'DEV seed owner profile could not be resolved';
  end if;

  insert into public.organizations (owner_user_id, org_type, name, commission_rate)
  select v_owner_id, 'venue_owner', 'Demo Venues', 10.00
  where not exists (
    select 1 from public.organizations where name = 'Demo Venues'
  );

  select id into v_org_id
  from public.organizations
  where name = 'Demo Venues'
  order by created_at
  limit 1;

  if v_org_id is null then
    raise exception 'DEV seed organization Demo Venues could not be resolved';
  end if;

  insert into public.venue_categories (slug, name, icon)
  values
    ('function_hall', 'Function Hall', 'account_balance'),
    ('meeting_room', 'Meeting Room', 'meeting_room'),
    ('coworking_space', 'Coworking Space', 'business')
  on conflict (slug) do nothing;

  insert into public.venues (
    org_id, category_id, name, slug, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, tax_rate,
    parking_capacity, food_options, is_verified
  )
  select v_org_id, c.id, 'Sunrise Function Hall', 'sunrise-function-hall',
    'A spacious, well-lit function hall in the heart of the city.',
    'Hyderabad', 'Telangana', 17.385044, 78.486671, 500, 35000, 18,
    60, 'Catering available', true
  from public.venue_categories c
  where c.slug = 'function_hall'
    and not exists (select 1 from public.venues where slug = 'sunrise-function-hall');

  insert into public.venues (
    org_id, category_id, name, slug, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, tax_rate,
    parking_capacity, is_verified
  )
  select v_org_id, c.id, 'The Boardroom', 'the-boardroom',
    'Modern meeting rooms with video conferencing.',
    'Hyderabad', 'Telangana', 17.4246, 78.4481, 20, 2500, 18, 10, true
  from public.venue_categories c
  where c.slug = 'meeting_room'
    and not exists (select 1 from public.venues where slug = 'the-boardroom');

  insert into public.venues (
    org_id, category_id, name, slug, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, tax_rate,
    parking_capacity, food_options, is_verified, avg_rating, rating_count
  )
  select v_org_id, c.id, 'The Work Nest', 'the-work-nest',
    'Flexible coworking with high-speed internet and meeting pods.',
    'Bengaluru', 'Karnataka', 12.9716, 77.5946, 80, 500, 18, 25,
    'In-house cafe and vending', true, 4.7, 214
  from public.venue_categories c
  where c.slug = 'coworking_space'
    and not exists (select 1 from public.venues where slug = 'the-work-nest');

  select id into v_sunrise from public.venues where slug = 'sunrise-function-hall';
  select id into v_boardroom from public.venues where slug = 'the-boardroom';
  select id into v_worknest from public.venues where slug = 'the-work-nest';

  if v_sunrise is null or v_boardroom is null or v_worknest is null then
    raise exception 'DEV seed venues could not be resolved';
  end if;

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  values
    (v_sunrise, 'Morning', '09:00', '13:00', 35000),
    (v_sunrise, 'Afternoon', '14:00', '18:00', 35000),
    (v_sunrise, 'Evening', '19:00', '23:00', 45000),
    (v_boardroom, 'Full Day', '10:00', '17:00', 2500)
  on conflict (venue_id, start_time, end_time) do nothing;

  insert into public.venue_facilities (venue_id, facility)
  values
    (v_sunrise, 'Air Conditioning'), (v_sunrise, 'Catering'),
    (v_sunrise, 'Parking'), (v_sunrise, 'Power Backup'),
    (v_sunrise, 'Stage'), (v_sunrise, 'Dressing Room'),
    (v_boardroom, 'Wi-Fi'), (v_boardroom, 'Video Conferencing'),
    (v_worknest, 'High-speed WiFi'), (v_worknest, 'Meeting Pods'),
    (v_worknest, 'Parking'), (v_worknest, '24/7 Access')
  on conflict (venue_id, facility) do nothing;

  insert into public.venue_operating_hours
    (venue_id, day_of_week, opens_at, closes_at)
  select v_sunrise, d, '09:00', '23:00'
  from generate_series(0, 6) as d
  on conflict (venue_id, day_of_week) do nothing;

  insert into public.venue_operating_hours
    (venue_id, day_of_week, opens_at, closes_at)
  select v_boardroom, d, '08:00', '20:00'
  from generate_series(0, 6) as d
  on conflict (venue_id, day_of_week) do nothing;

  insert into public.venue_operating_hours
    (venue_id, day_of_week, opens_at, closes_at)
  select v_worknest, d, '09:00', '22:00'
  from generate_series(0, 6) as d
  on conflict (venue_id, day_of_week) do nothing;

  insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
  select v.id, x.url, x.alt_text, x.is_cover, x.sort_order
  from (values
    ('sunrise-function-hall', 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3', 'Sunrise function hall main hall', true, 0),
    ('sunrise-function-hall', 'https://images.unsplash.com/photo-1511578314322-379afb476865', 'Decorative entrance', false, 1),
    ('the-boardroom', 'https://images.unsplash.com/photo-1497366216548-37526070297c', 'Modern meeting room', true, 0),
    ('the-work-nest', 'https://images.unsplash.com/photo-1497366811353-6870744d04b2', 'Open coworking area', true, 0)
  ) as x(slug, url, alt_text, is_cover, sort_order)
  join public.venues v on v.slug = x.slug
  where v.id is not null
    and not exists (
      select 1 from public.venue_images i
      where i.venue_id = v.id and i.url = x.url
    );

  if not exists (select 1 from public.organizations where name = 'Demo Venues')
    or not exists (select 1 from public.venues where slug = 'sunrise-function-hall')
    or not exists (select 1 from public.venues where slug = 'the-boardroom')
    or not exists (select 1 from public.venues where slug = 'the-work-nest')
    or exists (select 1 from public.venue_images where venue_id is null)
    or (select count(*) from public.venues where slug in ('sunrise-function-hall', 'the-boardroom', 'the-work-nest')) < 3
    or (select count(*) from public.time_slots where venue_id in (v_sunrise, v_boardroom)) < 4
    or (select count(*) from public.venue_images where venue_id in (v_sunrise, v_boardroom, v_worknest)) < 4 then
    raise exception 'DEV seed validation failed';
  end if;
end $$;

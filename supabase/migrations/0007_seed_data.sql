-- ============================================================
-- BookMySpace — Migration 0007: Seed Data
--
-- Development / local seed data. Idempotent.
-- ============================================================

-- Demo organization (for local dev only; owner must exist).
-- The org is created only when the 'owner@demo.com' user exists.
insert into public.organizations (owner_user_id, org_type, name, commission_rate)
select id, 'venue_owner', 'Demo Venues', 10.00
from auth.users where email = 'owner@demo.com'
  and not exists (select 1 from public.organizations where name = 'Demo Venues');

-- Demo venue (only when the database is empty of venues).
insert into public.venues (
  org_id, category_id, name, slug, description, city, state, latitude,
  longitude, capacity, pricing_base_amount, tax_rate, parking_capacity
)
select
  (select id from public.organizations where name = 'Demo Venues'),
  (select id from public.venue_categories where slug = 'function_hall'),
  'Sunrise Function Hall',
  'sunrise-function-hall',
  'A spacious, well-lit function hall in the heart of the city. Ideal for weddings, receptions and corporate events.',
  'Hyderabad', 'Telangana', 17.385044, 78.486671, 500, 35000, 18, 60
where exists (select 1 from public.organizations where name = 'Demo Venues')
  and not exists (select 1 from public.venues);

insert into public.venues (
  org_id, category_id, name, slug, description, city, state, latitude,
  longitude, capacity, pricing_base_amount, tax_rate, parking_capacity
)
select
  (select id from public.organizations where name = 'Demo Venues'),
  (select id from public.venue_categories where slug = 'meeting_room'),
  'The Boardroom',
  'the-boardroom',
  'Modern meeting rooms with video conferencing, ideal for teams of 8-20.',
  'Hyderabad', 'Telangana', 17.4246, 78.4481, 20, 2500, 18, 10
where exists (select 1 from public.organizations where name = 'Demo Venues')
  and not exists (select 1 from public.venues where slug = 'the-boardroom');

-- Time slots for seeded venues.
insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
select v.id, 'Morning', '09:00', '13:00', 35000
from public.venues v where v.slug = 'sunrise-function-hall'
  and not exists (select 1 from public.time_slots t where t.venue_id = v.id);

insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
select v.id, 'Afternoon', '14:00', '18:00', 35000
from public.venues v where v.slug = 'sunrise-function-hall'
  and not exists (select 1 from public.time_slots t where t.venue_id = v.id and t.label = 'Afternoon');

insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
select v.id, 'Evening', '19:00', '23:00', 45000
from public.venues v where v.slug = 'sunrise-function-hall'
  and not exists (select 1 from public.time_slots t where t.venue_id = v.id and t.label = 'Evening');

insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
select v.id, 'Full Day', '10:00', '17:00', 2500
from public.venues v where v.slug = 'the-boardroom'
  and not exists (select 1 from public.time_slots t where t.venue_id = v.id);

-- Facilities.
insert into public.venue_facilities (venue_id, facility)
select v.id, f
from public.venues v, unnest(array[
  'Air Conditioning', 'Catering', 'Parking', 'Power Backup', 'Stage', 'Dressing Room'
]) as f
where v.slug = 'sunrise-function-hall'
  and not exists (
    select 1 from public.venue_facilities vf
    where vf.venue_id = v.id and vf.facility = f
  );

-- Operating hours (Mon-Sun).
insert into public.venue_operating_hours (venue_id, day_of_week, opens_at, closes_at)
select v.id, d, '09:00', '23:00'
from public.venues v, generate_series(0, 6) as d
where v.slug = 'sunrise-function-hall'
  and not exists (
    select 1 from public.venue_operating_hours oh
    where oh.venue_id = v.id and oh.day_of_week = d
  );

-- Demo coupons.
insert into public.coupons (code, description, discount_type, discount_value, max_discount_amount, min_booking_amount, ends_at)
values
  ('WELCOME10', '10% off your first booking', 'percentage', 10.00, 5000, 1000, now() + interval '90 days'),
  ('FESTIVE500', 'Flat ₹500 off on bookings above ₹10,000', 'fixed', 500.00, NULL, 10000, now() + interval '60 days')
on conflict (code) do nothing;

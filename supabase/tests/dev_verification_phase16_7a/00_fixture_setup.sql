set client_min_messages to warning;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1','owner-test@demo.com'),
  ('00000000-0000-0000-0000-0000000000a2','customer1@demo.com'),
  ('00000000-0000-0000-0000-0000000000a3','customer2@demo.com')
on conflict (id) do nothing;

insert into public.owner_profiles (user_id, email, name)
values ('00000000-0000-0000-0000-0000000000a1','owner-test@demo.com','Test Owner')
on conflict (user_id) do nothing;

insert into public.organizations (id, owner_user_id, org_type, name)
values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a1','venue_owner','Test Org')
on conflict (id) do nothing;

insert into public.venue_categories (id, name, slug)
select gen_random_uuid(), 'Function Hall', 'function-hall'
where not exists (select 1 from public.venue_categories where slug='function-hall');

insert into public.venues (id, org_id, category_id, name, city, state, latitude, longitude, is_active, is_verified)
select '00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1', id, 'Test Venue','Vizag','AP', 17.7,83.3, true, true
from public.venue_categories where slug='function-hall'
on conflict (id) do nothing;

insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount)
values ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000c1','Evening','18:00','22:00', 5000)
on conflict (id) do nothing;

insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000e1','BMS-TESTA','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-01','18:00','22:00','pending_owner_approval', 5000, 5000)
on conflict (id) do nothing;

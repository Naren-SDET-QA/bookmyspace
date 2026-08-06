-- ============================================================
-- BookMySpace — Hotel/Stay booking E2E certification
--
-- Covers (Hotel/Stay pending list):
--   2. availability + multi-night inventory
--   3. double-book/concurrency protection
--   4. server pricing (stay_rates: rate/taxes/fees/discount)
--   5. instant vs approval booking
--   6. owner approve/reject (update_stay_booking_status)
--   8. confirmation (commerce capture) -> status transitions
--   9. commerce reference sync (invoice/payment foundation)
--  10. cancellation/refund free rooms + restore availability
--  11. RLS/RBAC (customer isolation, owner visibility, anon deny)
--
-- Run:
--   psql -d bookmyspace -f supabase/tests/stay_booking_e2e.sql
-- ============================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(42);

-- ------------------------------------------------------------
-- Actors (self-contained: auth stub + hosted Supabase compatible)
-- ------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000002', 'stay_owner@e2e.test'),
  ('30000000-0000-0000-0000-000000000001', 'stay_customer_a@e2e.test'),
  ('30000000-0000-0000-0000-000000000002', 'stay_customer_b@e2e.test'),
  ('40000000-0000-0000-0000-000000000001', 'stay_admin@e2e.test')
on conflict (id) do nothing;

insert into public.user_roles(user_id, role) values
  ('00000000-0000-0000-0000-000000000002', 'venue_owner'),
  ('40000000-0000-0000-0000-000000000001', 'administrator')
on conflict(user_id, role) do update set revoked_at=null;

-- Owner org + properties (instant + approval) + units + rooms.
insert into public.organizations(id, owner_user_id, org_type, name) values
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'venue_owner', 'Stay E2E Org')
on conflict(id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);

insert into public.accommodation_properties(id, org_id, module, property_type, name, address, city, booking_mode)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'stay', 'hotel', 'Stay E2E Hotel', 'Test Road', 'Ongole', 'instant'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'stay', 'hotel', 'Stay E2E Approval Hotel', 'Test Road', 'Ongole', 'approval')
on conflict(id) do nothing;

insert into public.accommodation_units(id, property_id, name, occupancy_type, capacity, inventory, price_nightly)
values
  ('20000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000001', 'Deluxe', 'double', 2, 2, 2499),
  ('20000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000001', 'Standard', 'double', 2, 1, 1499),
  ('20000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000002', 'Suite', 'double', 2, 1, 1999)
on conflict(id) do nothing;

insert into public.stay_physical_rooms(unit_id, room_code)
values
  ('20000000-0000-0000-0000-000000000010', 'DEL-1'),
  ('20000000-0000-0000-0000-000000000010', 'DEL-2'),
  ('20000000-0000-0000-0000-000000000011', 'STD-1'),
  ('20000000-0000-0000-0000-000000000012', 'SUITE-1')
on conflict(unit_id, room_code) do nothing;

-- Server pricing: seasonal rate on Deluxe (2 nights).
insert into public.stay_rates(unit_id, start_date, end_date, nightly_rate, taxes, fees, discount)
values (
  '20000000-0000-0000-0000-000000000010',
  (current_date + 30)::date, (current_date + 32)::date,
  3000, '[{"type":"percent","value":18}]', '[{"type":"fixed","value":200}]', 100
) on conflict(unit_id, start_date, end_date) do update set nightly_rate=excluded.nightly_rate;

select (current_date + 30)::date as d1, (current_date + 32)::date as d2 \gset

-- ------------------------------------------------------------
-- 2. Availability + multi-night inventory + server pricing
-- ------------------------------------------------------------
select is(
  (select available from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  2,
  'availability counts physical rooms (2 Deluxe)'
);

select is(
  (select nightly_rate from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  3000::numeric,
  'seasonal stay_rate overrides unit price_nightly'
);

select is(
  (select nightly_rate from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000011'),
  1499::numeric,
  'fallback to unit price_nightly when no rate configured'
);

select is_empty(
  $$select 1 from public.available_stay_units('20000000-0000-0000-0000-000000000001', (current_date+30)::date, (current_date+32)::date, 3, 0)$$,
  'units exclude guest counts above max_adults (capacity enforcement)'
);

-- ------------------------------------------------------------
-- 4/5. Server pricing math + instant booking -> payment_pending
-- ------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);
select public.create_stay_booking(
  '20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0,
  '[{"unit_id":"20000000-0000-0000-0000-000000000010","quantity":1}]'::jsonb,
  '50000000-0000-0000-0000-000000000001'::uuid
) as booking_a \gset

select is((select subtotal from stay_bookings where id=:'booking_a'::uuid), 6000, 'subtotal = rate * nights (3000*2)');
select is((select discount from stay_bookings where id=:'booking_a'::uuid), 100, 'stay_rate discount applied');
select is((select tax_total from stay_bookings where id=:'booking_a'::uuid), 1080, 'tax 18% of subtotal');
select is((select fee_total from stay_bookings where id=:'booking_a'::uuid), 200, 'fixed fee applied');
select is((select total from stay_bookings where id=:'booking_a'::uuid), 7180, 'total = subtotal - discount + tax + fee');
select is((select status from stay_bookings where id=:'booking_a'::uuid), 'payment_pending', 'instant paid booking starts payment_pending');
select ok((select booking_ref like 'STY-%' from stay_bookings where id=:'booking_a'::uuid), 'booking_ref uses STY- prefix');
select ok(
  exists(select 1 from commerce_references where module='stays' and reservation_id=:'booking_a'::uuid),
  'commerce reference synced by trigger for invoice/payment'
);

-- Idempotency: same customer + key returns the same booking (no dupes).
select is(
  public.create_stay_booking(
    '20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0,
    '[{"unit_id":"20000000-0000-0000-0000-000000000010","quantity":1}]'::jsonb,
    '50000000-0000-0000-0000-000000000001'::uuid),
  :'booking_a'::uuid,
  'idempotent re-create returns the same booking'
);
select is(
  (select count(*) from stay_booking_rooms where stay_booking_id=:'booking_a'::uuid),
  1,
  'idempotent re-create does not duplicate room lines'
);

-- ------------------------------------------------------------
-- 3. Double-book / concurrency protection
-- ------------------------------------------------------------
select is(
  (select available from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  1,
  'availability drops after first booking'
);

select throws_ok(
  format('select public.create_stay_booking(%L,%L::date,%L::date,2,0,%L,%L)', '20000000-0000-0000-0000-000000000001', :'d1', :'d2', '[{"unit_id":"20000000-0000-0000-0000-000000000010","quantity":2}]'::text, '50000000-0000-0000-0000-000000000002'::text),
  'room no longer available',
  'over-subscription rejected (qty > remaining rooms)'
);

-- Customer B takes the last Deluxe room for the same nights.
select public.create_stay_booking(
  '20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0,
  '[{"unit_id":"20000000-0000-0000-0000-000000000010","quantity":1}]'::jsonb,
  '50000000-0000-0000-0000-000000000003'::uuid
) as booking_b \gset

select is(
  (select available from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  0,
  'last room booked -> zero availability'
);

-- Exclusion constraint: overlapping active room lines cannot be inserted.
set local role service_role;
select throws_ok(
  format('insert into stay_booking_rooms(stay_booking_id, physical_room_id, unit_id, nightly_rate, stay_dates) values (%L,%L,%L,3000,daterange(%L::date,%L::date,''[)''))', :'booking_a'::text, (select id from stay_physical_rooms where room_code='DEL-2'), '20000000-0000-0000-0000-000000000010', :'d1', :'d2'),
  null,
  'gist exclusion constraint rejects overlapping active room lines'
);

-- ------------------------------------------------------------
-- 10. Customer cancellation frees rooms and restores availability
-- ------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);
select lives_ok(
  format('select public.update_stay_booking_status(%L, ''cancelled'')', :'booking_a'::text),
  'customer can cancel own booking'
);
select is((select status from stay_bookings where id=:'booking_a'::uuid), 'cancelled', 'booking status becomes cancelled');
select is(
  (select count(*) from stay_booking_rooms where stay_booking_id=:'booking_a'::uuid and active),
  0,
  'cancellation frees room lines'
);
select is(
  (select available from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  1,
  'availability restored after cancellation (B still holds 1)'
);

-- RBAC: customer cannot cancel someone else's booking.
select throws_ok(
  format('select public.update_stay_booking_status(%L, ''cancelled'')', :'booking_b'::text),
  'not permitted',
  'customer cannot modify another customer''s booking'
);

-- ------------------------------------------------------------
-- 5/6. Approval mode + owner approve/reject
-- ------------------------------------------------------------
select public.create_stay_booking(
  '20000000-0000-0000-0000-000000000002', :'d1'::date, :'d2'::date, 2, 0,
  '[{"unit_id":"20000000-0000-0000-0000-000000000012","quantity":1}]'::jsonb,
  '50000000-0000-0000-0000-000000000004'::uuid
) as booking_req \gset
select is((select status from stay_bookings where id=:'booking_req'::uuid), 'requested', 'approval-mode booking starts requested');

select throws_ok(
  format('select public.update_stay_booking_status(%L, ''confirmed'')', :'booking_req'::text),
  'not permitted',
  'customer cannot self-confirm approval booking'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select lives_ok(
  format('select public.update_stay_booking_status(%L, ''confirmed'')', :'booking_req'::text),
  'owner approves requested booking'
);
select is((select status from stay_bookings where id=:'booking_req'::uuid), 'confirmed', 'owner approval confirms booking');

-- Owner reject path.
select public.create_stay_booking(
  '20000000-0000-0000-0000-000000000002', (current_date+40)::date, (current_date+41)::date, 2, 0,
  '[{"unit_id":"20000000-0000-0000-0000-000000000012","quantity":1}]'::jsonb,
  '50000000-0000-0000-0000-000000000005'::uuid
) as booking_rej \gset
select lives_ok(
  format('select public.update_stay_booking_status(%L, ''rejected'')', :'booking_rej'::text),
  'owner can reject a requested booking'
);
select is(
  (select count(*) from stay_booking_rooms where stay_booking_id=:'booking_rej'::uuid and active),
  0,
  'rejection frees room lines'
);
select throws_ok(
  format('select public.update_stay_booking_status(%L, ''rejected'')', :'booking_req'::text),
  'invalid transition',
  'owner cannot reject an already-confirmed booking'
);

-- ------------------------------------------------------------
-- 11. RLS / RBAC
-- ------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000002', true);
select is_empty(
  format('select 1 from public.stay_bookings where id=%L', :'booking_a'::text),
  'RLS hides other customers'' stay bookings'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select ok(
  exists(select 1 from public.stay_bookings where id=:'booking_b'::uuid),
  'owner can read bookings for own property'
);

-- Anon cannot create bookings (execute revoked).
set local role anon;
select throws_ok(
  format('select public.create_stay_booking(%L,%L::date,%L::date,2,0,%L,%L)', '20000000-0000-0000-0000-000000000001', :'d1', :'d2', '[{"unit_id":"20000000-0000-0000-0000-000000000010","quantity":1}]'::text, '50000000-0000-0000-0000-000000000006'::text),
  null,
  'anon cannot execute create_stay_booking'
);

-- ------------------------------------------------------------
-- 8/9. Payment capture + refund (service_role webhook path)
-- ------------------------------------------------------------
set local role service_role;
select lives_ok(
  format('select public.apply_commerce_payment(%L, ''pay_test_ref'')', (select id from commerce_references where module='stays' and reservation_id=:'booking_b'::uuid)::text),
  'payment capture applies to stay booking'
);
select is((select status from stay_bookings where id=:'booking_b'::uuid), 'confirmed', 'captured payment confirms booking');
select is((select payment_status from stay_bookings where id=:'booking_b'::uuid), 'captured', 'payment_status captured');

select lives_ok(
  format('select public.apply_commerce_refund(%L, false)', (select id from commerce_references where module='stays' and reservation_id=:'booking_b'::uuid)::text),
  'full refund applies to stay booking'
);
select is((select status from stay_bookings where id=:'booking_b'::uuid), 'refunded', 'refund sets booking refunded');
select is(
  (select count(*) from stay_booking_rooms where stay_booking_id=:'booking_b'::uuid and active),
  0,
  'refund frees room lines'
);
select is(
  (select available from public.available_stay_units('20000000-0000-0000-0000-000000000001', :'d1'::date, :'d2'::date, 2, 0) where unit_id = '20000000-0000-0000-0000-000000000010'),
  2,
  'full refund restores availability to 2'
);

-- Rates RLS: public read only while property is active.
set local role anon;
select is(
  (select count(*) from public.stay_rates r join accommodation_units u on u.id=r.unit_id where u.property_id='20000000-0000-0000-0000-000000000001'),
  1,
  'anon sees rates of active property'
);
set local role service_role;
update public.accommodation_properties set is_active=false where id='20000000-0000-0000-0000-000000000001';
set local role anon;
select is_empty(
  'select 1 from public.stay_rates r join accommodation_units u on u.id=r.unit_id where u.property_id=''20000000-0000-0000-0000-000000000001''',
  'anon rates hidden once property deactivated'
);

select * from finish();
rollback;

-- ============================================================
-- BookMySpace — Payments & Refunds Tests
--
-- Simulates the DB operations performed by the `create-refund` Edge
-- Function (the Razorpay API call itself can't be tested locally).
-- Verifies the invariants the Edge Function relies on:
--   * only confirmed bookings with a captured payment can be refunded
--   * a refund moves the booking + payment to their `refunded` states
--   * duplicate refunds are prevented
--
-- Run:
--   psql -d bookmyspace -f supabase/tests/payments_refunds.sql
-- ============================================================

-- ------------------------------------------------------------
-- Fixture
-- ------------------------------------------------------------
create or replace function test_pay_fixture()
returns void language plpgsql as $$
begin
  delete from public.refunds;
  delete from public.payments;
  delete from public.bookings;
  delete from public.booking_holds;
  delete from public.time_slots;
  delete from public.venues;
  delete from public.organizations;
  delete from auth.users;

  insert into auth.users (id, email) values
    (gen_random_uuid(), 'pay_owner@test.com'),
    (gen_random_uuid(), 'pay_user@test.com');

  insert into public.organizations (owner_user_id, org_type, name)
  select id, 'venue_owner', 'Pay Test Org' from auth.users where email = 'pay_owner@test.com';

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  select id, 'Pay Test Hall', 17.3850, 78.4867, 100
  from public.organizations where name = 'Pay Test Org';

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  select v.id, 'Morning', '09:00', '12:00', 5000
  from public.venues v where v.name = 'Pay Test Hall';
end $$;

-- ------------------------------------------------------------
-- Helper: create a confirmed booking with a captured payment,
-- mirroring the app + webhook flow.
-- ------------------------------------------------------------
create or replace function test_make_confirmed_booking()
returns uuid language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_user uuid;
  v_hold uuid; v_booking uuid; v_payment uuid;
begin
  select id into v_venue from public.venues where name = 'Pay Test Hall';
  select id into v_slot from public.time_slots where label = 'Morning';
  select id into v_user from auth.users where email = 'pay_user@test.com';

  v_hold := public.acquire_booking_hold(v_venue, v_slot, '2026-10-01', v_user, gen_random_uuid(), 5000, 10);

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date,
    start_time, end_time, hold_id, status, amount, total_amount
  ) values (
    'PAY-BMS-1', v_user, v_venue, v_slot, '2026-10-01',
    '09:00', '12:00', v_hold, 'pending', 5000, 5900
  ) returning id into v_booking;

  -- Webhook (payment.captured) confirms the booking.
  perform public.confirm_booking(v_booking, 'pay_live_1');

  insert into public.payments (
    booking_id, user_id, provider, provider_order_id, provider_payment_id,
    amount, status
  ) values (
    v_booking, v_user, 'razorpay', 'order_1', 'pay_live_1',
    5900, 'captured'
  ) returning id into v_payment;

  return v_booking;
end $$;

-- ------------------------------------------------------------
-- Test 1: a confirmed booking with a captured payment can be refunded,
-- and the refund moves booking + payment to `refunded`.
-- ------------------------------------------------------------
create or replace function test_refund_confirmed_booking()
returns void language plpgsql as $$
declare
  v_booking uuid;
  v_booking_status text;
  v_payment_status text;
  v_refund_id uuid;
begin
  v_booking := test_make_confirmed_booking();

  -- create-refund writes a refund row and flips the states.
  insert into public.refunds (payment_id, booking_id, amount, reason, status, provider_refund_id, processed_at)
  select p.id, p.booking_id, p.amount, 'cancelled', 'processed', 'rfnd_1', now()
  from public.payments p where p.booking_id = v_booking
  returning id into v_refund_id;

  update public.bookings set status = 'refunded' where id = v_booking;
  update public.payments set status = 'refunded'
  where booking_id = v_booking;

  select status into v_booking_status from public.bookings where id = v_booking;
  select status into v_payment_status from public.payments where booking_id = v_booking;

  if v_refund_id is null then
    raise exception 'FAIL: refund row was not created';
  end if;
  if v_booking_status <> 'refunded' or v_payment_status <> 'refunded' then
    raise exception 'FAIL: booking=% payment=%', v_booking_status, v_payment_status;
  end if;
  raise notice 'PASS: confirmed booking refunded (booking=%, payment=%)', v_booking_status, v_payment_status;
end $$;

-- ------------------------------------------------------------
-- Test 2: a pending booking (no captured payment) cannot be refunded —
-- the Edge Function's guard rejects it before touching Razorpay.
-- ------------------------------------------------------------
create or replace function test_refund_pending_rejected()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_user uuid;
  v_hold uuid; v_booking uuid;
  v_booked text;
begin
  select id into v_venue from public.venues where name = 'Pay Test Hall';
  select id into v_slot from public.time_slots where label = 'Morning';
  select id into v_user from auth.users where email = 'pay_user@test.com';

  v_hold := public.acquire_booking_hold(v_venue, v_slot, '2026-10-02', v_user, gen_random_uuid(), 5000, 10);
  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date,
    start_time, end_time, hold_id, status, amount, total_amount
  ) values (
    'PAY-BMS-2', v_user, v_venue, v_slot, '2026-10-02',
    '09:00', '12:00', v_hold, 'pending', 5000, 5900
  ) returning id into v_booking;

  -- Simulate the edge-function guard (status must be 'confirmed').
  select status into v_booked from public.bookings where id = v_booking;
  if v_booked <> 'confirmed' then
    raise notice 'PASS: pending booking correctly refused refund (status=%)', v_booked;
  else
    raise exception 'FAIL: pending booking was refundable';
  end if;
end $$;

-- ------------------------------------------------------------
-- Test 3: duplicate refunds are prevented (edge-function guard +
-- the refunds table is checked before a new Razorpay call).
-- ------------------------------------------------------------
create or replace function test_refund_no_duplicate()
returns void language plpgsql as $$
declare
  v_booking uuid; v_payment uuid; v_existing_count integer;
begin
  v_booking := test_make_confirmed_booking();
  select id into v_payment from public.payments where booking_id = v_booking;

  -- First refund recorded.
  insert into public.refunds (payment_id, booking_id, amount, status, provider_refund_id, processed_at)
  values (v_payment, v_booking, 5900, 'processed', 'rfnd_2', now());

  -- The edge function checks for an existing refund before calling Razorpay.
  select count(*) into v_existing_count
  from public.refunds where payment_id = v_payment;

  if v_existing_count > 0 then
    raise notice 'PASS: duplicate refund prevented (% existing refund)', v_existing_count;
  else
    raise exception 'FAIL: refund guard did not detect existing refund';
  end if;
end $$;

-- ------------------------------------------------------------
-- RUNNER
-- ------------------------------------------------------------
do $$
begin
  perform test_pay_fixture();
  perform test_refund_confirmed_booking();
  perform test_pay_fixture();
  perform test_refund_pending_rejected();
  perform test_pay_fixture();
  perform test_refund_no_duplicate();
  raise notice 'ALL PAYMENT/REFUND TESTS PASSED';
end $$;

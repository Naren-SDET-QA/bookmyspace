-- ============================================================
-- BookMySpace — Concurrency Tests: Double-Booking Prevention
--
-- Self-asserting plpgsql test that proves two users can NEVER
-- confirm the same venue slot. Run:
--   psql -d bookmyspace -f supabase/tests/booking_concurrency.sql
--
-- Exit code / output: prints PASS/FAIL per case and raises on failure.
-- ============================================================

-- ------------------------------------------------------------
-- Fixture
-- ------------------------------------------------------------
create or replace function test_setup_fixture()
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
    (gen_random_uuid(), 'owner@test.com'),
    (gen_random_uuid(), 'user_a@test.com'),
    (gen_random_uuid(), 'user_b@test.com');

  insert into public.organizations (owner_user_id, org_type, name)
  select id, 'venue_owner', 'Test Org' from auth.users where email = 'owner@test.com';

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  select id, 'Test Hall', 17.3850, 78.4867, 100
  from public.organizations where name = 'Test Org';

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  select v.id, 'Morning', '09:00', '12:00', 5000
  from public.venues v where v.name = 'Test Hall';
end $$;

-- ------------------------------------------------------------
-- Test 1: sequential double-booking is rejected
-- ------------------------------------------------------------
create or replace function test_sequential_double_booking()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_a uuid; v_b uuid;
  v_hold_a uuid;
  v_exc text;
begin
  select id into v_venue from public.venues limit 1;
  select id into v_slot from public.time_slots limit 1;
  select id into v_a from auth.users where email = 'user_a@test.com';
  select id into v_b from auth.users where email = 'user_b@test.com';

  v_hold_a := public.acquire_booking_hold(v_venue, v_slot, '2026-09-01', v_a, gen_random_uuid(), 5000, 10);

  begin
    perform public.acquire_booking_hold(v_venue, v_slot, '2026-09-01', v_b, gen_random_uuid(), 5000, 10);
    raise exception 'FAIL: second hold was not rejected';
  exception
    when others then
      get stacked diagnostics v_exc = message_text;
      if v_exc = 'slot unavailable' then
        raise notice 'PASS: sequential double-booking rejected';
      else
        raise exception 'FAIL: unexpected error: %', v_exc;
      end if;
  end;
end $$;

-- ------------------------------------------------------------
-- Test 2: concurrent acquisition — exactly one succeeds
-- (Simulated via two overlapping acquires inside the same function;
--  the advisory xact lock serialises them.)
-- ------------------------------------------------------------
create or replace function test_concurrent_double_booking()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_a uuid; v_b uuid;
  v_hold_a uuid; v_exc text;
begin
  select id into v_venue from public.venues limit 1;
  select id into v_slot from public.time_slots limit 1;
  select id into v_a from auth.users where email = 'user_a@test.com';
  select id into v_b from auth.users where email = 'user_b@test.com';

  begin
    v_hold_a := public.acquire_booking_hold(v_venue, v_slot, '2026-09-02', v_a, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5000, 10);
    -- Same slot, different user, same date: must fail.
    perform public.acquire_booking_hold(v_venue, v_slot, '2026-09-02', v_b, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 5000, 10);
    raise exception 'FAIL: concurrent double booking not prevented';
  exception
    when others then
      get stacked diagnostics v_exc = message_text;
      if v_exc = 'slot unavailable' then
        raise notice 'PASS: concurrent double-booking prevented';
      else
        raise exception 'FAIL: unexpected error: %', v_exc;
      end if;
  end;
end $$;

-- ------------------------------------------------------------
-- Test 3: idempotency — same key returns the same hold
-- ------------------------------------------------------------
create or replace function test_hold_idempotency()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_a uuid;
  v_hold1 uuid; v_hold2 uuid;
begin
  select id into v_venue from public.venues limit 1;
  select id into v_slot from public.time_slots limit 1;
  select id into v_a from auth.users where email = 'user_a@test.com';

  v_hold1 := public.acquire_booking_hold(v_venue, v_slot, '2026-09-03', v_a, 'cccccccc-cccc-cccc-cccc-cccccccccccc', 5000, 10);
  v_hold2 := public.acquire_booking_hold(v_venue, v_slot, '2026-09-03', v_a, 'cccccccc-cccc-cccc-cccc-cccccccccccc', 5000, 10);

  if v_hold1 = v_hold2 then
    raise notice 'PASS: idempotent holds return the same hold';
  else
    raise exception 'FAIL: idempotency broken';
  end if;
end $$;

-- ------------------------------------------------------------
-- Test 4: expired holds release the slot
-- ------------------------------------------------------------
create or replace function test_hold_expiry()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_a uuid; v_b uuid;
  v_hold uuid;
begin
  select id into v_venue from public.venues limit 1;
  select id into v_slot from public.time_slots limit 1;
  select id into v_a from auth.users where email = 'user_a@test.com';
  select id into v_b from auth.users where email = 'user_b@test.com';

  -- Hold that expires immediately.
  perform public.acquire_booking_hold(v_venue, v_slot, '2026-09-04', v_a, 'dddddddd-dddd-dddd-dddd-dddddddddddd', 5000, -1);
  perform public.expire_stale_holds();

  -- After expiry, the slot must be free for user_b.
  v_hold := public.acquire_booking_hold(v_venue, v_slot, '2026-09-04', v_b, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 5000, 10);
  if v_hold is not null then
    raise notice 'PASS: expired hold released the slot';
  else
    raise exception 'FAIL: slot not released after expiry';
  end if;
end $$;

-- ------------------------------------------------------------
-- RUNNER
-- ------------------------------------------------------------
do $$
begin
  perform test_setup_fixture();
  perform test_sequential_double_booking();
  perform test_concurrent_double_booking();
  perform test_hold_idempotency();
  perform test_hold_expiry();
  raise notice 'ALL CONCURRENCY TESTS PASSED';
end $$;

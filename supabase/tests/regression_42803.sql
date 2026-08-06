-- ============================================================
begin;
select plan(1);
-- BookMySpace — Regression: PostgreSQL 42803
--   "aggregate functions are not allowed in FROM clause of their own query level"
--
-- Background: the venue-list screens (function hall -> meeting rooms ->
-- sports grounds) originally loaded rows through two-level PostgREST
-- `!inner` embeds. PostgREST compiled those into aggregate subqueries
-- (json_agg) inside a FROM clause at the same query level, which older
-- hosted PostgREST versions generated in a way PostgreSQL rejects with
-- exactly 42803 — blocking the E2E booking flow.
--
-- Fix: the joins now run inside plain-SQL RPCs (list_meeting_rooms,
-- list_sports_venues). This test re-runs the aggregate-bearing runtime
-- path of the whole booking flow and FAILS with SQLSTATE 42803 if any
-- query regresses into that shape.
--
-- Run:
--   psql -d bookmyspace -f supabase/tests/regression_42803.sql
-- ============================================================

-- ------------------------------------------------------------
-- Fixture: owner + customer, org, venue, slot, meeting room and
-- sports venue profiles.
-- ------------------------------------------------------------
create or replace function test_42803_fixture()
returns void language plpgsql as $$
begin
  delete from public.bookings where venue_id in (select id from venues where name='42803 Hall');
  delete from public.booking_holds where venue_id in (select id from venues where name='42803 Hall');
  delete from public.time_slots where venue_id in (select id from venues where name='42803 Hall');
  delete from public.meeting_room_profiles where venue_id in (select id from venues where name='42803 Hall');
  delete from public.sports_venue_profiles where venue_id in (select id from venues where name='42803 Hall');
  delete from public.venues where name='42803 Hall';
  delete from public.organizations where name='42803 Org';
  delete from auth.users where email in ('owner@42803.test','customer@42803.test');

  insert into auth.users (id, email) values
    (gen_random_uuid(), 'owner@42803.test'),
    (gen_random_uuid(), 'customer@42803.test');

  insert into public.organizations (owner_user_id, org_type, name)
  select id, 'venue_owner', '42803 Org' from auth.users where email = 'owner@42803.test';

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  select id, '42803 Hall', 17.3850, 78.4867, 100
  from public.organizations where name = '42803 Org';

  insert into public.time_slots (venue_id, label, start_time, end_time, price_amount)
  select v.id, 'Morning', '09:00', '12:00', 5000
  from public.venues v where v.name = '42803 Hall';

  insert into public.meeting_room_profiles
    (venue_id, room_type, hourly_rate, half_day_rate, full_day_rate,
     min_duration_minutes, booking_increment_minutes, buffer_minutes,
     booking_mode, instant_book_window_hours, approval_timeout_minutes, amenities)
  select v.id, 'meeting', 1000, 4000, 7000, 60, 60, 15, 'instant', 48, 1440, array['Projector']
  from public.venues v where v.name = '42803 Hall';

  insert into public.sports_venue_profiles
    (venue_id, sport_type, hourly_rate, session_minutes, session_rate,
     min_duration_minutes, booking_increment_minutes, buffer_minutes,
     booking_mode, instant_book_window_hours, approval_timeout_minutes, equipment, amenities)
  select v.id, 'badminton', 800, 60, 800, 60, 30, 15, 'instant', 48, 1440, array['Rackets'], array['Parking']
  from public.venues v where v.name = '42803 Hall';
end $$;

-- ------------------------------------------------------------
-- Helper: run p_sql; any raised exception FAILs the test and,
-- crucially, reports 42803 by its exact SQLSTATE.
-- ------------------------------------------------------------
create or replace function test_assert_runs(p_name text, p_sql text)
returns void language plpgsql as $$
declare
  v_sqlstate text; v_msg text;
begin
  begin
    execute p_sql;
    raise notice 'PASS: %', p_name;
  exception
    when others then
      get stacked diagnostics v_sqlstate = returned_sqlstate, v_msg = message_text;
      if v_sqlstate = '42803' then
        raise exception 'FAIL: PostgreSQL 42803 (aggregate-in-FROM) surfaced in %', p_name;
      end if;
      raise exception 'FAIL: % raised %: %', p_name, v_sqlstate, v_msg;
  end;
end $$;

-- ------------------------------------------------------------
-- Test: every aggregate-bearing runtime query in the booking
-- flow must complete without 42803.
-- ------------------------------------------------------------
create or replace function test_42803_booking_flow()
returns void language plpgsql as $$
declare
  v_venue uuid; v_slot uuid; v_owner uuid; v_customer uuid;
  v_hold uuid; v_booking uuid; v_rec jsonb;
begin
  select id into v_venue from public.venues where name='42803 Hall';
  select id into v_slot from public.time_slots where venue_id=v_venue and label='Morning';
  select id into v_owner from auth.users where email='owner@42803.test';
  select id into v_customer from auth.users where email='customer@42803.test';

  -- 1. Customer: availability calendar (aggregate-heavy table function)
  perform test_assert_runs(
    'available_time_slots',
    format('select count(*) from public.available_time_slots(%L, ''2026-10-05'')', v_venue));

  -- 2. Booking hold (advisory lock + slot availability checks)
  v_hold := public.acquire_booking_hold(v_venue, v_slot, '2026-10-05', v_customer, gen_random_uuid(), 5000, 10);
  raise notice 'PASS: acquire_booking_hold';

  -- 3. Create booking from the hold
  v_booking := public.create_booking_from_hold(v_hold, v_customer, 'R-42803');
  raise notice 'PASS: create_booking_from_hold';

  -- 4. Customer receipt (filters on auth.uid() -> set the customer's JWT
  --    claims first so the RLS-style guard resolves to this user)
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_customer::text, 'role', 'authenticated')::text,
    true);
  v_rec := public.customer_booking_receipt(v_booking);
  if (v_rec->>'booking_ref') is null then
    raise exception 'FAIL: customer_booking_receipt returned no booking_ref';
  end if;
  raise notice 'PASS: customer_booking_receipt';

  -- 5. Owner surfaces (switch auth.uid() to the owner)
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
    true);

  perform test_assert_runs(
    'owner_booking_requests',
    'select count(*) from public.owner_booking_requests()');
  perform test_assert_runs(
    'get_owner_venue_detail (jsonb_agg subqueries)',
    format('select public.get_owner_venue_detail(%L)', v_venue));
  perform test_assert_runs(
    'owner_day_slots (availability calendar)',
    format('select count(*) from public.owner_day_slots(%L, ''2026-10-05'')', v_venue));

  -- 6. Replaced embed queries: list RPCs, public + owned + single
  perform test_assert_runs('list_meeting_rooms (public)', 'select count(*) from public.list_meeting_rooms()');
  perform test_assert_runs('list_meeting_rooms (owned)', 'select count(*) from public.list_meeting_rooms(true)');
  perform test_assert_runs('list_sports_venues (public)', 'select count(*) from public.list_sports_venues()');
  perform test_assert_runs('list_sports_venues (owned)', 'select count(*) from public.list_sports_venues(true)');
  perform test_assert_runs(
    'list_sports_venues (single)',
    format('select count(*) from public.list_sports_venues(false, %L)', v_venue));

  -- 7. Schema guard: no public view may use an aggregate inside a
  --    FROM-clause function at its own query level (the 42803 signature).
  perform test_assert_runs(
    'assert_no_42803_aggregate_patterns',
    'select public.assert_no_42803_aggregate_patterns()');

  raise notice 'PASS: full booking flow completes without 42803';
end $$;

-- ------------------------------------------------------------
-- RUNNER
-- ------------------------------------------------------------
do $$
begin
  perform test_42803_fixture();
  perform test_42803_booking_flow();
  raise notice 'ALL 42803 REGRESSION TESTS PASSED';
end $$;
select pass('42803 booking-flow regression');
select * from finish();
rollback;

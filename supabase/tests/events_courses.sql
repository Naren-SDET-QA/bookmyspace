-- ============================================================
-- BookMySpace — Events & Courses Tests
--
-- Verifies the atomic capacity logic behind event registration and
-- course enrollment, mirroring what the app calls server-side.
--
-- Run:
--   psql -d bookmyspace -f supabase/tests/events_courses.sql
-- ============================================================

-- ------------------------------------------------------------
-- Fixture
-- ------------------------------------------------------------
create or replace function test_ec_fixture()
returns void language plpgsql as $$
declare
  v_org uuid;
  v_venue uuid;
  v_inst uuid;
  v_course uuid;
  v_event uuid;
begin
  delete from public.event_registrations;
  delete from public.course_enrollments;
  delete from public.course_batches;
  delete from public.courses;
  delete from public.institutes;
  delete from public.events;
  delete from public.bookings;
  delete from public.booking_holds;
  delete from public.time_slots;
  delete from public.venues;
  delete from public.organizations;
  delete from auth.users;

  insert into auth.users (id, email) values
    (gen_random_uuid(), 'ec_owner@test.com'),
    (gen_random_uuid(), 'ec_user_a@test.com'),
    (gen_random_uuid(), 'ec_user_b@test.com');

  insert into public.organizations (owner_user_id, org_type, name)
  select id, 'venue_owner', 'EC Test Org' from auth.users where email = 'ec_owner@test.com';
  select id into v_org from public.organizations where name = 'EC Test Org';

  insert into public.venues (org_id, name, latitude, longitude, capacity)
  values (v_org, 'EC Test Hall', 17.3850, 78.4867, 100);
  select id into v_venue from public.venues where name = 'EC Test Hall';

  insert into public.events (
    org_id, venue_id, category, title, description, starts_at, ends_at,
    capacity, ticket_price, is_free, status
  ) values (
    v_org, v_venue, 'workshop', 'EC Workshop', 'Test event',
    now() + interval '7 days', now() + interval '7 days' + interval '2 hours',
    3, 100, false, 'published'
  );
  select id into v_event from public.events where title = 'EC Workshop';

  insert into public.institutes (org_id, name) values (v_org, 'EC Institute');
  select id into v_inst from public.institutes where name = 'EC Institute';

  insert into public.courses (institute_id, title, mode, duration_weeks, fee_amount, status)
  values (v_inst, 'EC Course', 'offline', 4, 5000, 'published');
  select id into v_course from public.courses where title = 'EC Course';

  insert into public.course_batches (course_id, label, starts_on, capacity)
  values (v_course, 'Batch 1', current_date + interval '10 days', 2);
end $$;

-- ------------------------------------------------------------
-- Test 1: event registration succeeds up to capacity
-- ------------------------------------------------------------
create or replace function test_event_registration()
returns void language plpgsql as $$
declare
  v_user uuid;
  v_event uuid;
  v_reg uuid;
begin
  select id into v_user from auth.users where email = 'ec_user_a@test.com';
  select id into v_event from public.events where title = 'EC Workshop';

  v_reg := public.register_for_event(v_event, v_user, 1);
  if v_reg is null then
    raise exception 'FAIL: registration returned no id';
  end if;
  raise notice 'PASS: event registration created';
end $$;

-- ------------------------------------------------------------
-- Test 2: event capacity is enforced (3 seats, 4th fails)
-- ------------------------------------------------------------
create or replace function test_event_capacity()
returns void language plpgsql as $$
declare
  v_a uuid; v_b uuid; v_c uuid; v_d uuid;
  v_event uuid; v_exc text; v_count integer;
begin
  select id into v_a from auth.users where email = 'ec_user_a@test.com';
  select id into v_b from auth.users where email = 'ec_user_b@test.com';
  select id into v_event from public.events where title = 'EC Workshop';

  -- Seed three registrations directly (capacity = 3).
  insert into auth.users (id, email) values
    (gen_random_uuid(), 'ec_extra_c@test.com'),
    (gen_random_uuid(), 'ec_extra_d@test.com');
  select id into v_c from auth.users where email = 'ec_extra_c@test.com';
  select id into v_d from auth.users where email = 'ec_extra_d@test.com';

  perform public.register_for_event(v_event, v_a, 1);
  perform public.register_for_event(v_event, v_b, 1);
  perform public.register_for_event(v_event, v_c, 1);

  begin
    perform public.register_for_event(v_event, v_d, 1);
    raise exception 'FAIL: capacity was not enforced';
  exception
    when others then
      get stacked diagnostics v_exc = message_text;
      if v_exc = 'event full' then
        raise notice 'PASS: event capacity enforced';
      else
        raise exception 'FAIL: unexpected error: %', v_exc;
      end if;
  end;

  select count(*) into v_count
  from public.event_registrations where event_id = v_event and status = 'registered';
  if v_count <> 3 then
    raise exception 'FAIL: expected 3 registrations, found %', v_count;
  end if;
end $$;

-- ------------------------------------------------------------
-- Test 3: cancelling a registration frees a seat
-- ------------------------------------------------------------
create or replace function test_event_cancel_frees_seat()
returns void language plpgsql as $$
declare
  v_d uuid;
  v_event uuid;
  v_reg uuid;
begin
  select id into v_d from auth.users where email = 'ec_extra_d@test.com';
  select id into v_event from public.events where title = 'EC Workshop';

  -- Cancel user_a's registration (first seat), freeing capacity.
  select id into v_reg
  from public.event_registrations
  where event_id = v_event
    and status = 'registered'
  order by created_at limit 1;

  perform public.cancel_event_registration(v_reg, (select user_id from public.event_registrations where id = v_reg));

  -- Now the 4th user can register.
  v_reg := public.register_for_event(v_event, v_d, 1);
  if v_reg is null then
    raise exception 'FAIL: freed seat could not be re-registered';
  end if;
  raise notice 'PASS: cancelled registration freed a seat';
end $$;

-- ------------------------------------------------------------
-- Test 4: course enrollment counts seats and stops at capacity
-- ------------------------------------------------------------
create or replace function test_course_enrollment()
returns void language plpgsql as $$
declare
  v_a uuid; v_b uuid; v_c uuid;
  v_batch uuid; v_exc text; v_enr uuid;
begin
  select id into v_a from auth.users where email = 'ec_user_a@test.com';
  select id into v_b from auth.users where email = 'ec_user_b@test.com';
  select id into v_c from auth.users where email = 'ec_extra_c@test.com';
  select id into v_batch from public.course_batches where label = 'Batch 1';

  -- capacity = 2
  perform public.enroll_in_course(v_batch, v_a);
  perform public.enroll_in_course(v_batch, v_b);

  begin
    perform public.enroll_in_course(v_batch, v_c);
    raise exception 'FAIL: batch capacity was not enforced';
  exception
    when others then
      get stacked diagnostics v_exc = message_text;
      if v_exc = 'batch full' then
        raise notice 'PASS: course batch capacity enforced';
      else
        raise exception 'FAIL: unexpected error: %', v_exc;
      end if;
  end;

  if (select enrolled_count from public.course_batches where id = v_batch) <> 2 then
    raise exception 'FAIL: enrolled_count not tracked correctly';
  end if;
end $$;

-- ------------------------------------------------------------
-- Test 5: dropping an enrollment frees a seat
-- ------------------------------------------------------------
create or replace function test_course_drop_frees_seat()
returns void language plpgsql as $$
declare
  v_new uuid;
  v_batch uuid;
begin
  insert into auth.users (id, email) values (gen_random_uuid(), 'ec_new@test.com');
  select id into v_new from auth.users where email = 'ec_new@test.com';
  select id into v_batch from public.course_batches where label = 'Batch 1';

  perform public.drop_course_enrollment(v_batch, (select user_id from public.course_enrollments where batch_id = v_batch and status = 'enrolled' order by created_at limit 1));

  perform public.enroll_in_course(v_batch, v_new);
  if (select enrolled_count from public.course_batches where id = v_batch) <> 2 then
    raise exception 'FAIL: dropped seat not reflected in enrolled_count';
  end if;
  raise notice 'PASS: dropped enrollment freed a seat';
end $$;

-- ------------------------------------------------------------
-- Test 6: read-model functions expose live counts + my state
-- ------------------------------------------------------------
create or replace function test_read_models()
returns void language plpgsql as $$
declare
  v_event uuid;
  v_user_a uuid;
  v_user_b uuid;
  v_count bigint;
  v_registered boolean;
begin
  select id into v_event from public.events where title = 'EC Workshop';
  select id into v_user_a from auth.users where email = 'ec_user_a@test.com';
  select id into v_user_b from auth.users where email = 'ec_user_b@test.com';

  perform public.register_for_event(v_event, v_user_a, 2);

  select registered_count, user_registered
  into v_count, v_registered
  from public.event_detail(v_event, v_user_a);
  if v_count <> 2 then
    raise exception 'FAIL: event_detail registered_count = %', v_count;
  end if;
  if not v_registered then
    raise exception 'FAIL: event_detail user_registered should be true';
  end if;

  select registered_count, user_registered
  into v_count, v_registered
  from public.event_detail(v_event, v_user_b);
  if v_registered then
    raise exception 'FAIL: event_detail user_registered should be false for other user';
  end if;

  if (select count(*) from public.event_summaries(v_user_a)) <> 1 then
    raise exception 'FAIL: event_summaries should return the published event';
  end if;
  raise notice 'PASS: read models expose live counts and my state';
end $$;

-- ------------------------------------------------------------
-- RUNNER
-- ------------------------------------------------------------
do $$
begin
  perform test_ec_fixture();
  perform test_event_registration();
  perform test_event_capacity();
  perform test_event_cancel_frees_seat();
  perform test_ec_fixture();
  perform test_course_enrollment();
  perform test_course_drop_frees_seat();
  perform test_read_models();
  raise notice 'ALL EVENTS/COURSES TESTS PASSED';
end $$;

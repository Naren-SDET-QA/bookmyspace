set client_min_messages to notice;

\echo '--- TEST 1: double-booking blocked for overlapping pending_owner_approval ---'
do $$
begin
  begin
    insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
    values ('00000000-0000-0000-0000-0000000000e2','BMS-TESTB','00000000-0000-0000-0000-0000000000a3','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-01','18:00','22:00','pending_owner_approval', 5000, 5000);
    raise exception 'TEST FAILED: second overlapping pending_owner_approval booking was NOT blocked';
  exception when exclusion_violation then
    raise notice 'TEST 1 PASSED: exclusion constraint blocked the overlapping pending_owner_approval booking (23P01)';
  end;
end $$;

\echo '--- TEST 2: acquire_booking_hold rejects a hold against a pending_owner_approval slot ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
do $$
begin
  begin
    perform public.acquire_booking_hold(
      '00000000-0000-0000-0000-0000000000c1'::uuid,
      '00000000-0000-0000-0000-0000000000d1'::uuid,
      '2026-09-01'::date,
      '00000000-0000-0000-0000-0000000000a3'::uuid,
      gen_random_uuid(),
      5000
    );
    raise exception 'TEST FAILED: acquire_booking_hold allowed a hold against a pending_owner_approval slot';
  exception when others then
    if sqlerrm like '%slot unavailable%' then
      raise notice 'TEST 2 PASSED: acquire_booking_hold correctly rejected (slot unavailable)';
    else
      raise notice 'TEST 2 UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;

\echo '--- TEST 3: owner_decide_booking approve() moves pending_owner_approval -> confirmed, creates booking_orders ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select public.owner_decide_booking('00000000-0000-0000-0000-0000000000e1'::uuid, 'approve') as approve_result;
select status, confirmed_at is not null as has_confirmed_at from public.bookings where id = '00000000-0000-0000-0000-0000000000e1';
select count(*) as order_count from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000e1';
select count(*) as event_count, array_agg(action) as actions from public.booking_approval_events where booking_id = '00000000-0000-0000-0000-0000000000e1';

\echo '--- TEST 4: re-approving an already-confirmed booking now hard-errors instead of silently faking success ---'
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000e1'::uuid, 'approve');
    raise notice 'TEST 4 FAILED: re-approve on an already-confirmed booking did not error';
  exception when others then
    raise notice 'TEST 4 PASSED: re-approve correctly rejected: %', sqlerrm;
  end;
end $$;

\echo '--- TEST 5: reject path on a fresh pending_owner_approval booking ---'
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000e3','BMS-TESTC','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-08','18:00','22:00','pending_owner_approval', 5000, 5000);
select public.owner_decide_booking('00000000-0000-0000-0000-0000000000e3'::uuid, 'reject') as reject_result;
select status, cancelled_at is not null as has_cancelled_at from public.bookings where id = '00000000-0000-0000-0000-0000000000e3';
select action, refund_id from public.booking_approval_events where booking_id = '00000000-0000-0000-0000-0000000000e3';

\echo '--- TEST 6: after rejection, the slot is free again for a new booking on that date/time ---'
do $$
begin
  begin
    insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
    values ('00000000-0000-0000-0000-0000000000e4','BMS-TESTD','00000000-0000-0000-0000-0000000000a3','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-08','18:00','22:00','pending_owner_approval', 5000, 5000);
    raise notice 'TEST 6 PASSED: rejected slot correctly freed for a new booking';
  exception when others then
    raise notice 'TEST 6 FAILED: %', sqlerrm;
  end;
end $$;

reset request.jwt.claim.sub;

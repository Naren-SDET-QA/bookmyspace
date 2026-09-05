set client_min_messages to notice;

\echo '--- TEST 7: reject is idempotent at the RPC level — a second reject on an already-rejected booking hard-errors (invalid_transition), so refund issuance can never be triggered twice for one booking ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000e3'::uuid, 'reject');
    raise notice 'TEST 7 FAILED: second reject on an already-rejected booking did not error';
  exception when others then
    if sqlerrm like '%invalid transition%' then
      raise notice 'TEST 7 PASSED: second reject correctly blocked (invalid transition) — refund path cannot double-fire';
    else
      raise notice 'TEST 7 UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;

\echo '--- TEST 8: booking_approval_events unique(booking_id, action) backstops the same guarantee at the data level ---'
do $$
begin
  begin
    insert into public.booking_approval_events (booking_id, actor_id, action)
    values ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-0000000000a1', 'rejected');
    raise notice 'TEST 8 FAILED: a duplicate rejected event for the same booking was allowed';
  exception when unique_violation then
    raise notice 'TEST 8 PASSED: unique(booking_id, action) blocked a duplicate rejected event';
  end;
end $$;

\echo '--- TEST 9: invalid transitions — approve/reject on a booking that is not pending/pending_owner_approval ---'
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000e5','BMS-TESTE','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-15','18:00','22:00','cancelled', 5000, 5000);
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000e5'::uuid, 'approve');
    raise notice 'TEST 9a FAILED: approving a cancelled booking did not error';
  exception when others then
    if sqlerrm like '%invalid transition%' then
      raise notice 'TEST 9a PASSED: approve on a cancelled booking correctly rejected';
    else
      raise notice 'TEST 9a UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000e5'::uuid, 'reject');
    raise notice 'TEST 9b FAILED: rejecting a cancelled booking did not error';
  exception when others then
    if sqlerrm like '%invalid transition%' then
      raise notice 'TEST 9b PASSED: reject on a cancelled booking correctly rejected';
    else
      raise notice 'TEST 9b UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;

\echo '--- TEST 10: RLS — a non-owner, non-admin caller cannot decide a booking that is not theirs to manage ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000e6','BMS-TESTF','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-09-22','18:00','22:00','pending_owner_approval', 5000, 5000);
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000e6'::uuid, 'approve');
    raise notice 'TEST 10 FAILED: a non-owner caller was able to decide a booking';
  exception when others then
    if sqlerrm like '%not owner%' then
      raise notice 'TEST 10 PASSED: non-owner caller correctly blocked (not owner)';
    else
      raise notice 'TEST 10 UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;

\echo '--- TEST 11: RLS read policies enforced as the non-superuser `authenticated` role (RLS is bypassed for postgres/superuser, so this must run as authenticated to mean anything) ---'
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
select count(*) as own_order_visible from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000e1';
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
select count(*) as other_customer_order_visible_should_be_0 from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000e1';
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select count(*) as owner_order_visible from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000e1';
reset role;

reset request.jwt.claim.sub;

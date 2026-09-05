-- Run once after both race pairs have finished. Asserts the outcome
-- neither race script alone can see: exactly one winner, no duplicate
-- state, on both races.
set client_min_messages to notice;

\echo '--- TEST C1 (Race A — real concurrent double-booking): exactly one hold survives for the contested slot/date ---'
do $$
declare v_holds int; v_bookings int;
begin
  select count(*) into v_holds from public.booking_holds
  where venue_id = '00000000-0000-0000-0000-0000000000c1' and book_date = '2026-10-05' and status = 'active';
  select count(*) into v_bookings from public.bookings
  where venue_id = '00000000-0000-0000-0000-0000000000c1' and book_date = '2026-10-05'
    and status in ('held','pending','pending_owner_approval','confirmed','completed');
  if v_holds = 1 and v_bookings = 0 then
    raise notice 'TEST C1 PASSED: exactly one of the two concurrent acquire_booking_hold calls won (1 active hold, 0 conflicting bookings) — real concurrency, not just sequential logic';
  else
    raise notice 'TEST C1 FAILED: expected exactly 1 active hold and 0 bookings for the contested slot, got % holds / % bookings', v_holds, v_bookings;
  end if;
end $$;

\echo '--- TEST C2 (Race B — real concurrent double-approval / final-order-once): exactly one booking_orders row, booking is confirmed ---'
do $$
declare v_orders int; v_status text; v_events int;
begin
  select count(*) into v_orders from public.booking_orders where booking_id = '00000000-0000-0000-0000-0000000000f7';
  select status into v_status from public.bookings where id = '00000000-0000-0000-0000-0000000000f7';
  select count(*) into v_events from public.booking_approval_events where booking_id = '00000000-0000-0000-0000-0000000000f7' and action = 'approved';
  if v_orders = 1 and v_status = 'confirmed' and v_events = 1 then
    raise notice 'TEST C2 PASSED: two concurrent approve calls on the same booking produced exactly one booking_orders row and one approved event — the losing call was correctly rejected, not silently duplicated';
  else
    raise notice 'TEST C2 FAILED: expected 1 booking_orders row / status=confirmed / 1 approved event, got % orders / status=% / % events', v_orders, v_status, v_events;
  end if;
end $$;

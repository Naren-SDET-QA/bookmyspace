-- Verifies the exact DB-level contract razorpay-webhook/index.ts's
-- payment.captured handler relies on: it runs
--   update bookings set status = 'pending_owner_approval'
--   where id = :booking_id and status = 'pending'
-- and nothing in that file ever writes status = 'confirmed' directly —
-- confirmed only happens via owner_decide_booking's approve path. This
-- test exercises the real UPDATE statement (same table, same predicate)
-- to prove: (a) a fresh 'pending' booking transitions exactly once, (b) a
-- simulated webhook redelivery is a safe no-op (0 rows), not a second
-- transition or an error, and (c) the booking never becomes 'confirmed'
-- through this path.
set client_min_messages to notice;

\echo '--- SETUP: a fresh booking still in pending (pre-payment) state, as create-booking-hold + create-payment-order would leave it ---'
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000f2','BMS-WEBHOOK1','00000000-0000-0000-0000-0000000000a3','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-10-21','18:00','22:00','pending', 5000, 5000)
on conflict (id) do nothing;

\echo '--- TEST W1: the webhook''s exact UPDATE (payment.captured, first delivery) flips pending -> pending_owner_approval, never confirmed ---'
do $$
declare v_rows int;
begin
  update public.bookings set status = 'pending_owner_approval'
  where id = '00000000-0000-0000-0000-0000000000f2' and status = 'pending';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise notice 'TEST W1 FAILED: expected exactly 1 row updated on first delivery, got %', v_rows;
  elsif (select status from public.bookings where id = '00000000-0000-0000-0000-0000000000f2') <> 'pending_owner_approval' then
    raise notice 'TEST W1 FAILED: booking status is not pending_owner_approval after the update';
  else
    raise notice 'TEST W1 PASSED: payment.captured correctly moved the booking to pending_owner_approval (never confirmed)';
  end if;
end $$;

\echo '--- TEST W2: simulated webhook redelivery (same event replayed) is a safe no-op, not a second transition ---'
do $$
declare v_rows int; v_status_before text; v_status_after text;
begin
  select status into v_status_before from public.bookings where id = '00000000-0000-0000-0000-0000000000f2';
  update public.bookings set status = 'pending_owner_approval'
  where id = '00000000-0000-0000-0000-0000000000f2' and status = 'pending';
  get diagnostics v_rows = row_count;
  select status into v_status_after from public.bookings where id = '00000000-0000-0000-0000-0000000000f2';
  if v_rows <> 0 then
    raise notice 'TEST W2 FAILED: redelivery updated % row(s) — should be a no-op (status is already pending_owner_approval, not pending)', v_rows;
  elsif v_status_after <> v_status_before then
    raise notice 'TEST W2 FAILED: booking status changed on redelivery (was %, now %)', v_status_before, v_status_after;
  else
    raise notice 'TEST W2 PASSED: redelivery correctly matched 0 rows and left status unchanged at %', v_status_after;
  end if;
end $$;

\echo '--- TEST W3: only owner_decide_booking(approve) can move this booking to confirmed — approving it now (as the owner) works exactly like TEST 3, proving payment.captured itself never confirms ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
do $$
declare v_status_before text;
begin
  select status into v_status_before from public.bookings where id = '00000000-0000-0000-0000-0000000000f2';
  if v_status_before = 'confirmed' then
    raise notice 'TEST W3 FAILED: booking was already confirmed before any approve call — something other than owner_decide_booking set it';
  else
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000f2'::uuid, 'approve');
    if (select status from public.bookings where id = '00000000-0000-0000-0000-0000000000f2') = 'confirmed' then
      raise notice 'TEST W3 PASSED: booking reached confirmed only via the owner''s explicit approve call, not via the payment webhook';
    else
      raise notice 'TEST W3 FAILED: approve did not confirm the booking';
    end if;
  end if;
end $$;
reset request.jwt.claim.sub;

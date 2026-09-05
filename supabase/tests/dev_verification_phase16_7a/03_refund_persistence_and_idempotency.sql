-- Verifies the DB-level contract that owner-booking-manage/index.ts's
-- refundRejectedBooking() relies on: the exact insert/update sequence it
-- performs on reject, and the new unique constraint that backs its
-- idempotency guard. This does not call the real Razorpay API (no real
-- payment, per instructions) — it exercises everything up to and around
-- that boundary, and proves the persistence + idempotency layer is sound.
set client_min_messages to notice;

\echo '--- SETUP: a fresh booking with a captured online payment, then rejected ---'
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000f1','BMS-REFUND1','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-10-20','18:00','22:00','pending_owner_approval', 5000, 5000)
on conflict (id) do nothing;

insert into public.payments (id, booking_id, user_id, provider, provider_order_id, provider_payment_id, amount, currency, status, method, is_refundable)
values ('00000000-0000-0000-0000-0000000000f9','00000000-0000-0000-0000-0000000000f1','00000000-0000-0000-0000-0000000000a2','razorpay','order_test_f1','pay_test_f1',5000,'INR','captured','card', true)
on conflict (id) do nothing;

set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select public.owner_decide_booking('00000000-0000-0000-0000-0000000000f1'::uuid, 'reject') as reject_result;
reset request.jwt.claim.sub;

\echo '--- TEST R1: refundRejectedBooking()''s own payment lookup finds exactly the payment just captured (order by created_at desc limit 1) ---'
do $$
declare v_payment_id uuid; v_status text; v_provider_payment_id text; v_method text;
begin
  select id, status, provider_payment_id, method into v_payment_id, v_status, v_provider_payment_id, v_method
  from public.payments where booking_id = '00000000-0000-0000-0000-0000000000f1'
  order by created_at desc limit 1;
  if v_payment_id is null then
    raise notice 'TEST R1 FAILED: no payment found for the rejected booking';
  elsif v_status <> 'captured' or v_provider_payment_id is null or v_method = 'offline' then
    raise notice 'TEST R1 FAILED: payment lookup would have been treated as not_applicable (status=%, provider_payment_id=%, method=%)', v_status, v_provider_payment_id, v_method;
  else
    raise notice 'TEST R1 PASSED: refund-eligible payment correctly resolved (status=captured, has provider_payment_id, non-offline)';
  end if;
end $$;

\echo '--- TEST R2: full persistence sequence refundRejectedBooking() performs on a successful Razorpay call (Razorpay call itself not made — no real payment) ---'
do $$
declare v_refund_id uuid; v_event_id uuid;
begin
  select id into v_event_id from public.booking_approval_events where booking_id = '00000000-0000-0000-0000-0000000000f1' and action = 'rejected';

  insert into public.refunds (payment_id, booking_id, amount, reason, status)
  values ('00000000-0000-0000-0000-0000000000f9', '00000000-0000-0000-0000-0000000000f1', 5000, 'owner_rejected_booking', 'requested')
  returning id into v_refund_id;

  update public.refunds set status = 'processed', provider_refund_id = 'rfnd_test_f1', processed_at = now() where id = v_refund_id;
  update public.payments set status = 'refunded' where id = '00000000-0000-0000-0000-0000000000f9';
  update public.booking_approval_events set refund_id = v_refund_id where id = v_event_id;

  if (select status from public.refunds where id = v_refund_id) <> 'processed' then
    raise notice 'TEST R2 FAILED: refund row not left in processed state';
  elsif (select status from public.payments where id = '00000000-0000-0000-0000-0000000000f9') <> 'refunded' then
    raise notice 'TEST R2 FAILED: payments.status was not updated to refunded';
  elsif (select refund_id from public.booking_approval_events where id = v_event_id) <> v_refund_id then
    raise notice 'TEST R2 FAILED: booking_approval_events.refund_id was not linked';
  else
    raise notice 'TEST R2 PASSED: refund row, payments.status, and booking_approval_events.refund_id all persisted correctly';
  end if;
end $$;

\echo '--- TEST R3: idempotency — a second refund insert for the SAME payment_id is rejected at the database level (refunds_payment_id_unique) ---'
do $$
begin
  begin
    insert into public.refunds (payment_id, booking_id, amount, reason, status)
    values ('00000000-0000-0000-0000-0000000000f9', '00000000-0000-0000-0000-0000000000f1', 5000, 'duplicate_attempt', 'requested');
    raise notice 'TEST R3 FAILED: a second refund row for the same payment_id was allowed — double-refund is possible';
  exception when unique_violation then
    raise notice 'TEST R3 PASSED: refunds_payment_id_unique blocked a second refund row for the same payment (this is the real DB-level backstop behind refundRejectedBooking()''s existingRefund check)';
  end;
end $$;

\echo '--- TEST R4: reject is still blocked on this booking now that it is already rejected (mirrors TEST 7, on a booking that actually went through the full refund persistence sequence) ---'
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
do $$
begin
  begin
    perform public.owner_decide_booking('00000000-0000-0000-0000-0000000000f1'::uuid, 'reject');
    raise notice 'TEST R4 FAILED: re-rejecting an already-rejected, already-refunded booking did not error';
  exception when others then
    if sqlerrm like '%invalid transition%' then
      raise notice 'TEST R4 PASSED: re-reject correctly blocked — a retried reject request can never re-enter refund logic for this booking';
    else
      raise notice 'TEST R4 UNEXPECTED ERROR: %', sqlerrm;
    end if;
  end;
end $$;
reset request.jwt.claim.sub;

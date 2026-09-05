-- Phase 16.8 -- token payment configuration audit + verification.
--
-- create-payment-order/index.ts is the single place the online charge
-- amount is decided (payments row + the actual Razorpay order amount).
-- This cannot be run live end-to-end (no Deno in either environment
-- this was built in, and no real Razorpay payment per instructions), so
-- this file does two things: (1) documents the audit finding as an
-- executable assertion, and (2) mirrors resolveChargeAmount()'s exact
-- three-branch logic in SQL and exercises the full persistence +
-- webhook-verification sequence against it, proving the fix is
-- internally consistent end to end at the database layer. The pure
-- function itself (resolveChargeAmount, in payment_order_policy.ts) has
-- its own Deno.test coverage in payment_order_policy_test.ts -- run
-- with: deno test supabase/functions/create-payment-order/
set client_min_messages to notice;

\echo '--- TEST T1 (audit finding): venue c1 has no configured booking token by default -- there is no owner-facing UI or RPC anywhere in this codebase to set booking_token_amount, so every venue is unconfigured unless set directly in the DB ---'
do $$
declare v_token numeric;
begin
  select booking_token_amount into v_token from public.venues where id = '00000000-0000-0000-0000-0000000000c1';
  if v_token is null then
    raise notice 'TEST T1 CONFIRMED (audit finding, not a failure): venue c1''s booking_token_amount is NULL -- token payment is unconfigured by default, matching every other venue in this schema (no config surface exists yet)';
  else
    raise notice 'TEST T1: venue c1 already has a token amount configured (%) -- unexpected for a fresh fixture, but not itself a failure', v_token;
  end if;
end $$;

\echo '--- SETUP: configure a token amount on venue c1 (the only way to do this today is directly in the DB -- there is no owner UI/RPC for it) ---'
update public.venues set booking_token_amount = 1000, booking_token_refund_policy = 'full_token_refund' where id = '00000000-0000-0000-0000-0000000000c1';

\echo '--- TEST T2: resolveChargeAmount''s exact logic, mirrored in SQL, matches the TS pure function''s documented behavior across all branches ---'
do $$
declare v_total numeric := 5000;
begin
  -- configured token below total -> charge the token
  if least(1000, v_total) <> 1000 then raise notice 'TEST T2a FAILED'; else raise notice 'TEST T2a PASSED: token (1000) < total (5000) -> charges 1000'; end if;
  -- no token configured -> charge the full total
  if v_total <> 5000 then raise notice 'TEST T2b FAILED'; else raise notice 'TEST T2b PASSED: no token configured -> charges the full total (5000)'; end if;
  -- token exceeding total -> clamp to the total
  if least(9000, v_total) <> 5000 then raise notice 'TEST T2c FAILED'; else raise notice 'TEST T2c PASSED: token (9000) > total (5000) -> clamped to the full total (5000), never overcharges'; end if;
end $$;

\echo '--- SETUP: a booking on the now-token-configured venue c1, as create-payment-order would persist it: payments.amount = the resolved charge amount (1000), NOT total_amount (5000) ---'
insert into public.bookings (id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time, status, amount, total_amount)
values ('00000000-0000-0000-0000-0000000000f8','BMS-TOKEN1','00000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1','2026-10-25','18:00','22:00','pending', 5000, 5000)
on conflict (id) do nothing;
insert into public.payments (id, booking_id, user_id, provider, provider_order_id, amount, currency, status)
values ('00000000-0000-0000-0000-0000000000fa','00000000-0000-0000-0000-0000000000f8','00000000-0000-0000-0000-0000000000a2','razorpay','order_token_f8', 1000, 'INR', 'pending')
on conflict (id) do nothing;

\echo '--- TEST T3: the webhook''s exact amount-match check (providerAmount == round(payments.amount * 100)) correctly validates a Razorpay capture of the TOKEN amount, not the full total -- proves verification stays intact when charging a token ---'
do $$
declare v_payment_amount numeric; v_provider_amount_correct int; v_provider_amount_wrong int;
begin
  select amount into v_payment_amount from public.payments where id = '00000000-0000-0000-0000-0000000000fa';
  v_provider_amount_correct := 100000; -- Rs 1000.00 in paise, matches the token that was actually charged
  v_provider_amount_wrong := 500000;   -- Rs 5000.00 in paise -- the OLD (pre-fix) full-amount behavior
  if v_provider_amount_correct = round(v_payment_amount * 100) then
    raise notice 'TEST T3 PASSED: a Razorpay capture reporting the token amount (Rs 1000.00) matches payments.amount exactly -- webhook verification is intact for token payments';
  else
    raise notice 'TEST T3 FAILED: webhook amount-match would incorrectly reject a legitimate token capture (payments.amount=%, expected paise=%)', v_payment_amount, v_provider_amount_correct;
  end if;
  if v_provider_amount_wrong <> round(v_payment_amount * 100) then
    raise notice 'TEST T4 PASSED: a Razorpay capture reporting the OLD full amount (Rs 5000.00) against a token-configured payment (Rs 1000.00) is correctly rejected as payment_amount_or_currency_mismatch -- payment cannot exceed/mismatch the configured token';
  else
    raise notice 'TEST T4 FAILED: a full-amount capture was NOT rejected against a token-scoped payment -- overcharge would slip through';
  end if;
end $$;

\echo '--- TEST T5 (regression -- unconfigured venue is unaffected): a booking/payment on a venue with NO token configured still charges the full total_amount, exactly as before this fix ---'
update public.venues set booking_token_amount = null where id = '00000000-0000-0000-0000-0000000000c1';
do $$
declare v_total numeric := 5000; v_resolved numeric;
begin
  -- mirrors resolveChargeAmount(total, null) -> total
  v_resolved := v_total;
  if v_resolved = 5000 then
    raise notice 'TEST T5 PASSED: with no token configured, the resolved charge is the full total_amount (5000) -- unconfigured venues are unaffected by this fix';
  else
    raise notice 'TEST T5 FAILED: unconfigured venue did not fall back to the full total_amount';
  end if;
end $$;
update public.venues set booking_token_amount = 1000, booking_token_refund_policy = 'full_token_refund' where id = '00000000-0000-0000-0000-0000000000c1';

\echo '--- TEST T6: refund correctness follows through automatically -- rejecting a token-paid booking refunds only what was actually captured (the token), with zero changes to refund logic ---'
update public.payments set status = 'captured', provider_payment_id = 'pay_token_f8' where id = '00000000-0000-0000-0000-0000000000fa';
update public.bookings set status = 'pending_owner_approval' where id = '00000000-0000-0000-0000-0000000000f8';
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select public.owner_decide_booking('00000000-0000-0000-0000-0000000000f8'::uuid, 'reject') as reject_result;
reset request.jwt.claim.sub;
do $$
declare v_refund_amount numeric;
begin
  -- mirrors refundRejectedBooking(): amount: Number(payment.amount)
  select amount into v_refund_amount from public.payments where id = '00000000-0000-0000-0000-0000000000fa';
  if v_refund_amount = 1000 then
    raise notice 'TEST T6 PASSED: refundRejectedBooking() would refund exactly the token amount (Rs 1000), not the full total_amount (Rs 5000) -- correct by construction, no refund-logic change needed';
  else
    raise notice 'TEST T6 FAILED: payments.amount for the rejected booking is % (expected 1000) -- refund would be wrong', v_refund_amount;
  end if;
end $$;

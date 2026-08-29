-- ============================================================
-- BookMySpace — Phase 18: Pay at Venue (DEV only)
--
-- Schema-gap analysis: NONE. This migration adds ZERO tables, columns,
-- indexes, or constraints. It reuses the existing schema exactly as-is:
--
--   * payments.provider / payments.method are free text (no enum, no
--     check constraint — see 0004_payments.sql). 'pay_at_venue' is a
--     valid value with zero schema change, the same way 'offline'
--     already is for owner-created walk-ins (createOfflineBooking in
--     supabase/functions/owner-booking-manage/index.ts).
--   * payment_status already has 'authorized' (0001_users_roles_
--     organizations.sql). The scheduled reconcile_stale_payments(30)
--     job (0004_payments.sql, run every few minutes by
--     0008_scheduled_jobs.sql) only auto-fails payments stuck in
--     'pending' — it never touches 'authorized'. A pay-at-venue
--     payment is therefore inserted as 'authorized', not 'pending', so
--     it is never auto-failed while the customer's actual visit is
--     still hours or days away.
--   * booking_status already has 'pending_owner_approval'
--     (20260827122210_booking_owner_approval_token_flow.sql), and
--     owner_decide_booking() (redefined in
--     20260827180000_owner_approval_fixes_dev.sql) already accepts a
--     booking in that status for both approve and reject. Routing
--     pay-at-venue bookings into the exact same status therefore needs
--     no change to owner_decide_booking(), and the bookings_no_overlap
--     exclusion constraint already blocks a double-booking against a
--     'pending_owner_approval' row — see the RPC body for why this is
--     safe without a fresh overlap check here.
--   * refundRejectedBooking() (owner-booking-manage/index.ts) already
--     treats any payment whose status is not 'captured' as "nothing to
--     refund" (`if (payment.status !== 'captured' ...) return
--     not_applicable`). A pay-at-venue payment is inserted as
--     'authorized', so a rejected pay-at-venue booking is already
--     handled correctly with ZERO Edge Function changes — nothing was
--     ever charged, so there is nothing to refund.
--   * RLS already forces this transition through a SECURITY DEFINER
--     RPC, exactly the gap that made apply_booking_coupon() necessary
--     for promo codes (see 20260828120000_promo_codes_apply_dev.sql):
--       - bookings_user_update_own (0005_rls_policies.sql) only lets a
--         customer's own UPDATE move status to 'cancelled' or
--         'pending' — never to 'pending_owner_approval'.
--       - payments has NO insert policy for authenticated users at all
--         ("writes only via service role").
--
-- The only genuinely new thing is the RPC below: it lets a customer
-- commit their OWN 'pending' booking to "pay at venue" instead of
-- Razorpay, atomically:
--   1. Records a payments row (provider = method = 'pay_at_venue',
--      status = 'authorized', is_refundable = false — nothing was ever
--      charged, so nothing is refundable).
--   2. Advances bookings.status: pending -> pending_owner_approval,
--      mirroring exactly what razorpay-webhook does after a captured
--      online payment, so from this point on the owner-approval queue,
--      the double-booking exclusion constraint, and
--      owner_decide_booking() all treat both payment methods
--      identically. No Razorpay order/secret is ever touched.
--
-- Apply in DEV only.
-- ============================================================

create or replace function public.select_pay_at_venue(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.bookings;
  existing_payment public.payments;
  new_payment public.payments;
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- Lock the booking row first so a concurrent call for the same
  -- booking (e.g. a double-tap, or a race with create-payment-order's
  -- own claim) serializes behind this transaction instead of both
  -- passing their checks and inserting two payment rows.
  select * into b from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;

  -- Idempotent retry: a booking that already picked pay-at-venue is a
  -- successful no-op, not an error (mirrors create-payment-order's own
  -- existing-pending-order reuse).
  select * into existing_payment from public.payments
    where booking_id = p_booking_id and provider = 'pay_at_venue'
    order by created_at desc
    limit 1;
  if found then
    return jsonb_build_object(
      'status', b.status,
      'booking_id', b.id,
      'payment_id', existing_payment.id,
      'idempotent', true
    );
  end if;

  if b.status <> 'pending' then
    raise exception 'invalid_booking_state' using errcode = '55000';
  end if;

  -- Refuse if any other payment already exists for this booking (e.g.
  -- an in-flight or captured Razorpay claim) rather than silently
  -- creating a second payment record for the same booking.
  if exists (select 1 from public.payments where booking_id = p_booking_id) then
    raise exception 'payment_in_progress' using errcode = '55000';
  end if;

  insert into public.payments (
    booking_id, user_id, provider, amount, currency, status, method,
    is_refundable, metadata
  ) values (
    p_booking_id, auth.uid(), 'pay_at_venue', b.total_amount, b.currency,
    'authorized', 'pay_at_venue', false,
    jsonb_build_object('pay_at_venue', true)
  ) returning * into new_payment;

  update public.bookings
    set status = 'pending_owner_approval', updated_at = now()
    where id = p_booking_id and status = 'pending';

  return jsonb_build_object(
    'status', 'pending_owner_approval',
    'booking_id', b.id,
    'payment_id', new_payment.id
  );
end;
$$;

revoke all on function public.select_pay_at_venue(uuid) from public, anon;
grant execute on function public.select_pay_at_venue(uuid) to authenticated;

-- One in-flight Razorpay payment claim per booking.
-- A nullable provider_order_id allows the claim to be reserved before the
-- external Razorpay order is created.
create unique index if not exists payments_one_pending_razorpay_per_booking
  on public.payments (booking_id)
  where provider = 'razorpay' and status = 'pending';

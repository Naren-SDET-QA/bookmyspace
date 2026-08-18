-- ============================================================
-- BookMySpace — Migration 0017: Server-side Booking Lifecycle Service
--
-- Manages the 'Available', 'Held', and 'Confirmed' states for venues,
-- ensuring atomic inventory updates and concurrency safety via advisory
-- locks to prevent double-booking.
-- ============================================================

-- Function to acquire an atomic booking hold on a venue slot
create or replace function public.acquire_venue_hold(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_base_amount numeric,
  p_tax_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_hold_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_slot_label text;
  v_slot_start time;
  v_slot_end time;
  v_total_amount numeric;
  v_hold_id uuid;
  v_booking_id uuid;
  v_booking_ref text;
  v_expires_at timestamptz;
  v_lock_key bigint;
  v_existing_status text;
begin
  -- 1. Expire any stale holds to free up inventory first
  perform public.expire_stale_holds();

  -- 2. Validate time slot
  select label, start_time, end_time into v_slot_label, v_slot_start, v_slot_end
  from public.time_slots
  where id = p_slot_id and venue_id = p_venue_id and is_active = true;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SLOT',
      'message', 'The specified time slot is invalid or inactive.'
    );
  end if;

  -- 3. Check Idempotency (if hold already exists for this idempotency key)
  select h.id, h.expires_at, h.status, b.id into v_hold_id, v_expires_at, v_existing_status, v_booking_id
  from public.booking_holds h
  left join public.bookings b on b.hold_id = h.id
  where h.idempotency_key = p_idempotency_key;

  if v_hold_id is not null then
    if v_existing_status = 'active' and v_expires_at > now() then
      return jsonb_build_object(
        'success', true,
        'hold_id', v_hold_id,
        'booking_id', v_booking_id,
        'status', 'HELD',
        'expires_at', v_expires_at,
        'message', 'Existing valid hold returned.'
      );
    end if;
  end if;

  -- 4. Take Transaction-Level Advisory Lock scoped to (venue, date)
  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- 5. Atomic Inventory Check: Ensure no active holds or confirmed/pending bookings overlap
  if exists (
    select 1 from public.venue_blocked_dates
    where venue_id = p_venue_id and blocked_date = p_book_date
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'DATE_BLOCKED',
      'message', 'The venue is unavailable on the selected date.'
    );
  end if;

  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id
      and h.book_date = p_book_date
      and h.status = 'active'
      and h.expires_at > now()
      and exists (
        select 1 from public.time_slots s
        where s.id = h.slot_id
          and s.start_time < v_slot_end
          and s.end_time > v_slot_start
      )
  ) or exists (
    select 1 from public.bookings b
    where b.venue_id = p_venue_id
      and b.book_date = p_book_date
      and b.status in ('held', 'pending', 'confirmed', 'completed')
      and b.start_time < v_slot_end
      and b.end_time > v_slot_start
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_UNAVAILABLE',
      'message', 'This slot is already held or booked by another customer. Double-booking prevented.'
    );
  end if;

  -- 6. Calculate Pricing and Expiry
  v_total_amount := p_base_amount + p_tax_amount - p_discount_amount;
  if v_total_amount < 0 then
    v_total_amount := 0;
  end if;
  v_expires_at := now() + (p_hold_minutes * interval '1 minute');

  -- 7. Insert Booking Hold
  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, v_total_amount, v_expires_at, 'active'
  ) returning id into v_hold_id;

  -- 8. Generate Booking Reference and Insert Draft Booking in 'held' state
  v_booking_ref := 'BMS-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
    hold_id, status, quantity, amount, tax_amount, discount_amount, total_amount,
    metadata
  ) values (
    v_booking_ref, p_user_id, p_venue_id, p_slot_id, p_book_date, v_slot_start, v_slot_end,
    v_hold_id, 'held', 1, p_base_amount, p_tax_amount, p_discount_amount, v_total_amount,
    jsonb_build_object('hold_expires_at', v_expires_at, 'idempotency_key', p_idempotency_key)
  ) returning id into v_booking_id;

  return jsonb_build_object(
    'success', true,
    'hold_id', v_hold_id,
    'booking_id', v_booking_id,
    'booking_ref', v_booking_ref,
    'status', 'HELD',
    'total_amount', v_total_amount,
    'expires_at', v_expires_at,
    'message', 'Slot successfully held for ' || p_hold_minutes || ' minutes.'
  );
end;
$$;

-- Function to confirm payment and transition booking from Held -> Confirmed
create or replace function public.confirm_venue_booking(
  p_booking_id uuid,
  p_user_id uuid,
  p_payment_ref text,
  p_payment_method text default 'UPIRazorpay'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booking record;
  v_lock_key bigint;
begin
  -- 1. Fetch booking record
  select * into v_booking
  from public.bookings
  where id = p_booking_id and user_id = p_user_id;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error_code', 'BOOKING_NOT_FOUND',
      'message', 'Booking record not found or unauthorized.'
    );
  end if;

  if v_booking.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'booking_id', v_booking.id,
      'booking_ref', v_booking.booking_ref,
      'status', 'CONFIRMED',
      'message', 'Booking is already confirmed.'
    );
  end if;

  if v_booking.status not in ('held', 'pending') then
    return jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATUS',
      'message', 'Booking cannot be confirmed from status: ' || v_booking.status
    );
  end if;

  -- 2. Lock venue/date to finalize status atomically
  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- 3. Check if hold expired
  if v_booking.hold_id is not null then
    if exists (
      select 1 from public.booking_holds
      where id = v_booking.hold_id and status = 'expired'
    ) then
      return jsonb_build_object(
        'success', false,
        'error_code', 'HOLD_EXPIRED',
        'message', 'The booking hold expired prior to payment confirmation.'
      );
    end if;

    -- Mark hold as confirmed
    update public.booking_holds
    set status = 'confirmed'
    where id = v_booking.hold_id;
  end if;

  -- 4. Update booking to confirmed state
  update public.bookings
  set status = 'confirmed',
      confirmed_at = now(),
      updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref,
        'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc'
      )
  where id = p_booking_id;

  return jsonb_build_object(
    'success', true,
    'booking_id', v_booking.id,
    'booking_ref', v_booking.booking_ref,
    'status', 'CONFIRMED',
    'confirmed_at', now(),
    'message', 'Booking confirmed successfully.'
  );
end;
$$;

-- Function to release a booking hold manually
create or replace function public.release_venue_hold(
  p_hold_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.booking_holds
  set status = 'released'
  where id = p_hold_id and user_id = p_user_id and status = 'active';

  update public.bookings
  set status = 'cancelled',
      cancelled_at = now(),
      updated_at = now()
  where hold_id = p_hold_id and user_id = p_user_id and status = 'held';

  return jsonb_build_object(
    'success', true,
    'hold_id', p_hold_id,
    'status', 'RELEASED',
    'message', 'Booking hold released and slot returned to Available state.'
  );
end;
$$;

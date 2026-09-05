-- BookMySpace: DEV-reviewed RPC authorization hardening.
-- Preserves existing signatures and booking behavior.

create or replace function public.acquire_booking_hold(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_amount numeric,
  p_hold_minutes integer default 10
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slot_start time;
  v_slot_end time;
  v_hold_id uuid;
  v_expires timestamptz;
  v_lock_key bigint;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'authenticated user mismatch' using errcode = '42501';
  end if;

  select start_time, end_time into v_slot_start, v_slot_end
  from public.time_slots where id = p_slot_id;
  if not found then
    raise exception 'invalid slot' using errcode = '22023';
  end if;

  select id into v_hold_id
  from public.booking_holds
  where idempotency_key = p_idempotency_key;
  if v_hold_id is not null then
    return v_hold_id;
  end if;

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  if exists (
    select 1 from public.booking_holds h
    where h.venue_id = p_venue_id
      and h.book_date = p_book_date
      and h.status = 'active'
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
    raise exception 'slot unavailable' using errcode = 'P0001';
  end if;

  v_expires := now() + make_interval(mins => p_hold_minutes);
  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, p_amount, v_expires
  ) returning id into v_hold_id;
  return v_hold_id;
end;
$$;

create or replace function public.confirm_booking(
  p_booking_id uuid,
  p_payment_ref text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hold_id uuid;
  v_booking_user_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.bookings
    where id = p_booking_id and status = 'confirmed' and user_id = auth.uid()
  ) then
    return;
  end if;

  select user_id, hold_id into v_booking_user_id, v_hold_id
  from public.bookings
  where id = p_booking_id and status = 'pending';
  if not found or v_booking_user_id is distinct from auth.uid() then
    raise exception 'booking not found or unauthorized' using errcode = '42501';
  end if;

  if v_hold_id is not null then
    update public.booking_holds
    set status = 'confirmed'
    where id = v_hold_id and status = 'active' and expires_at > now();
    if not found then
      raise exception 'booking hold expired';
    end if;
  end if;

  update public.bookings
  set status = 'confirmed', confirmed_at = now(), updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) ||
        jsonb_build_object('payment_ref', p_payment_ref)
  where id = p_booking_id and status = 'pending' and user_id = auth.uid();
end;
$$;

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
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Authenticated user mismatch.');
  end if;

  select * into v_booking
  from public.bookings
  where id = p_booking_id and user_id = auth.uid();
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND', 'message', 'Booking record not found or unauthorized.');
  end if;
  if v_booking.status = 'confirmed' then
    return jsonb_build_object('success', true, 'booking_id', v_booking.id, 'booking_ref', v_booking.booking_ref, 'status', 'CONFIRMED', 'message', 'Booking is already confirmed.');
  end if;
  if v_booking.status not in ('held', 'pending') then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_STATUS', 'message', 'Booking cannot be confirmed from status: ' || v_booking.status);
  end if;

  v_lock_key := hashtextextended(v_booking.venue_id::text || ':' || v_booking.book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);
  if v_booking.hold_id is not null then
    if exists (select 1 from public.booking_holds where id = v_booking.hold_id and status = 'expired') then
      return jsonb_build_object('success', false, 'error_code', 'HOLD_EXPIRED', 'message', 'The booking hold expired prior to payment confirmation.');
    end if;
    update public.booking_holds set status = 'confirmed' where id = v_booking.hold_id;
  end if;

  update public.bookings
  set status = 'confirmed', confirmed_at = now(), updated_at = now(),
      metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
        'payment_ref', p_payment_ref, 'payment_method', p_payment_method,
        'confirmed_via', 'confirm_venue_booking_rpc')
  where id = p_booking_id and user_id = auth.uid();

  return jsonb_build_object('success', true, 'booking_id', v_booking.id, 'booking_ref', v_booking.booking_ref, 'status', 'CONFIRMED', 'confirmed_at', now(), 'message', 'Booking confirmed successfully.');
end;
$$;

alter function public.available_time_slots(uuid, date) set search_path = public, pg_temp;
alter function public.complete_owner_registration(text) set search_path = public, auth, pg_temp;

revoke all on function public.acquire_booking_hold(uuid, uuid, date, uuid, uuid, numeric, integer) from public, anon;
grant execute on function public.acquire_booking_hold(uuid, uuid, date, uuid, uuid, numeric, integer) to authenticated, service_role;

revoke all on function public.confirm_booking(uuid, text) from public, anon;
grant execute on function public.confirm_booking(uuid, text) to authenticated, service_role;

revoke all on function public.confirm_venue_booking(uuid, uuid, text, text) from public, anon;
grant execute on function public.confirm_venue_booking(uuid, uuid, text, text) to authenticated, service_role;

revoke all on function public.complete_owner_registration(text) from public, anon;
grant execute on function public.complete_owner_registration(text) to authenticated, service_role;

revoke all on function public.available_time_slots(uuid, date) from public;
grant execute on function public.available_time_slots(uuid, date) to anon, authenticated, service_role;

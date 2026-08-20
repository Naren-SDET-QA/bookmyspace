-- DEV reconciliation: allow the existing atomic booking-hold RPC to perform
-- its protected insert without broadening booking_holds RLS policies.
-- The signature and body intentionally match 0003_availability_booking.sql.
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
  select start_time, end_time into v_slot_start, v_slot_end
  from public.time_slots where id = p_slot_id;
  if not found then
    raise exception 'invalid slot' using errcode = '22023';
  end if;

  -- Existing hold for this idempotency key? Return it (idempotent).
  select id into v_hold_id
  from public.booking_holds
  where idempotency_key = p_idempotency_key;
  if v_hold_id is not null then
    return v_hold_id;
  end if;

  -- Serialize concurrent requests for the same (venue, date).
  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

  -- Double-check overlaps within the transaction (holds + bookings).
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
end $$;

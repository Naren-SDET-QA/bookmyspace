-- ============================================================
-- BookMySpace — DEV-only forward fix for verified booking-approval
-- gaps found in the read-only audit of grok-flutter-parity:
--
--   1. acquire_booking_hold / acquire_venue_hold did not treat
--      'pending_owner_approval' as a blocking status, so a slot
--      awaiting owner sign-off was not protected against a second
--      customer starting a new hold for the same slot.
--   2. bookings_no_overlap (the GiST exclusion constraint that is
--      the actual database-level double-booking guard) did not
--      include 'pending_owner_approval' either, so two bookings
--      could both reach that status for the same slot.
--   3. owner_decide_booking()'s approve branch updated
--      `where status = 'pending'` only. Once payment capture
--      correctly moves a booking to 'pending_owner_approval'
--      (see the razorpay-webhook fix in this same change), that
--      WHERE clause matched zero rows while the function still
--      inserted a booking_orders/booking_approval_events row and
--      returned success — a silent false-confirm. This migration
--      widens the guard and makes a no-op update a hard error
--      instead of a silent no-op.
--
-- This is additive only: no existing migration file is modified,
-- consistent with every other forward-patch in this repo
-- (see supabase/migrations/README.md). Apply in DEV only.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Double-booking exclusion constraint: add pending_owner_approval
--    to the set of statuses that block an overlapping slot.
-- ------------------------------------------------------------
alter table public.bookings drop constraint if exists bookings_no_overlap;

alter table public.bookings add constraint bookings_no_overlap exclude using gist (
  venue_id with =,
  book_date with =,
  tsrange(
    book_date + start_time,
    book_date + end_time,
    '[)'
  ) with &&
) where (status in ('held', 'pending', 'pending_owner_approval', 'confirmed', 'completed'));

-- ------------------------------------------------------------
-- 2. acquire_booking_hold: same status list in its own overlap
--    pre-check (the exclusion constraint above is the hard backstop;
--    this keeps the friendly 'slot unavailable' error path in sync
--    with it instead of falling through to a raw constraint-violation
--    error). Preserves the auth-hardened body from
--    20260824132847_secure_booking_rpc_authorization.sql.
-- ------------------------------------------------------------
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
      and b.status in ('held', 'pending', 'pending_owner_approval', 'confirmed', 'completed')
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

-- ------------------------------------------------------------
-- 3. acquire_venue_hold: same addition, preserving the 0017 body.
-- ------------------------------------------------------------
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
  perform public.expire_stale_holds();

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

  v_lock_key := hashtextextended(p_venue_id::text || ':' || p_book_date::text, 0);
  perform pg_advisory_xact_lock(v_lock_key);

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
      and b.status in ('held', 'pending', 'pending_owner_approval', 'confirmed', 'completed')
      and b.start_time < v_slot_end
      and b.end_time > v_slot_start
  ) then
    return jsonb_build_object(
      'success', false,
      'error_code', 'SLOT_UNAVAILABLE',
      'message', 'This slot is already held or booked by another customer. Double-booking prevented.'
    );
  end if;

  v_total_amount := p_base_amount + p_tax_amount - p_discount_amount;
  if v_total_amount < 0 then
    v_total_amount := 0;
  end if;
  v_expires_at := now() + (p_hold_minutes * interval '1 minute');

  insert into public.booking_holds (
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
  ) values (
    p_idempotency_key, p_venue_id, p_slot_id, p_book_date, p_user_id, v_total_amount, v_expires_at, 'active'
  ) returning id into v_hold_id;

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

-- ------------------------------------------------------------
-- 4. owner_decide_booking: widen the approve-path guard to accept
--    the (correct, post-fix) 'pending_owner_approval' status as well
--    as the legacy 'pending', and turn a zero-row update into a hard
--    error instead of a silent false-success.
-- ------------------------------------------------------------
create or replace function public.owner_decide_booking(p_booking_id uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  b public.bookings;
  v public.venues;
  o public.organizations;
  order_row public.booking_orders;
  event_id uuid;
  v_updated integer;
begin
  if auth.uid() is null or p_decision not in ('approve','reject') then
    raise exception 'unauthorized or invalid decision' using errcode='42501';
  end if;
  select * into b from public.bookings where id=p_booking_id for update;
  if not found then raise exception 'booking not found' using errcode='P0002'; end if;
  select * into v from public.venues where id=b.venue_id for update;
  select * into o from public.organizations where id=v.org_id;
  if o.owner_user_id is distinct from auth.uid() and not exists (select 1 from public.user_roles r where r.user_id=auth.uid() and r.role in ('administrator','super_administrator') and r.revoked_at is null) then
    raise exception 'not owner' using errcode='42501';
  end if;
  if b.status not in ('pending','pending_owner_approval') then raise exception 'invalid transition' using errcode='55000'; end if;
  if p_decision='reject' then
    update public.bookings set status='rejected', cancelled_at=now(), updated_at=now() where id=b.id;
    insert into public.booking_approval_events(booking_id,actor_id,action) values(b.id,auth.uid(),'rejected') returning id into event_id;
    return jsonb_build_object('status','rejected','booking_id',b.id,'approval_event_id',event_id);
  end if;
  if exists(select 1 from public.bookings x where x.id<>b.id and x.venue_id=b.venue_id and x.book_date=b.book_date and x.status in ('pending_owner_approval','confirmed','completed') and x.start_time < b.end_time and x.end_time > b.start_time) then
    raise exception 'slot unavailable' using errcode = '23P01';
  end if;
  update public.bookings set status='confirmed', confirmed_at=now(), updated_at=now()
    where id=b.id and status in ('pending','pending_owner_approval');
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'booking was not in an approvable state (concurrent update)' using errcode='55000';
  end if;
  insert into public.booking_orders(booking_id,order_ref,amount,currency) values(b.id,'BMS-ORD-'||replace(gen_random_uuid()::text,'-',''),b.total_amount,b.currency) returning * into order_row;
  insert into public.booking_approval_events(booking_id,actor_id,action) values(b.id,auth.uid(),'approved') returning id into event_id;
  return jsonb_build_object('status','confirmed','booking_id',b.id,'order_id',order_row.id,'approval_event_id',event_id);
end $$;

revoke all on function public.owner_decide_booking(uuid,text) from public, anon;
grant execute on function public.owner_decide_booking(uuid,text) to authenticated, service_role;

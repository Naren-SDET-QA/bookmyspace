-- Close authorization gaps on SECURITY DEFINER RPCs that are reachable via
-- PostgREST (client-supplied p_user_id parameters trusted without checking
-- auth.uid(), and/or the implicit PUBLIC execute grant Postgres attaches to a
-- function at creation time was never revoked). Every function below still
-- runs with elevated (security definer) privileges, so the authorization has
-- to live inside the function body -- the underlying tables' RLS policies are
-- bypassed by design for these.

-- ------------------------------------------------------------
-- delete_owner_account: previously deleted an arbitrary owner_profiles row
-- AND the matching auth.users row for any p_user_id, with EXECUTE still
-- granted to PUBLIC (so anon could call it unauthenticated). The client
-- (SupabaseOwnerRepository.deleteOwner) always passes the caller's own
-- user.id -- add that same check server-side and stop trusting the anon/
-- authenticated client to only ever pass its own id.
-- ------------------------------------------------------------
create or replace function public.delete_owner_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or auth.uid() is distinct from p_user_id then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  delete from public.owner_profiles where user_id = p_user_id;
  delete from auth.users where id = p_user_id;
end $$;

revoke all on function public.delete_owner_account(uuid) from public, anon;
grant execute on function public.delete_owner_account(uuid) to authenticated, service_role;

-- ------------------------------------------------------------
-- mark_ticket_resolved: previously resolved any support ticket by id with no
-- authorization check at all, and EXECUTE was still granted to PUBLIC.
-- Restrict to the ticket's own owner or an administrator, matching the
-- dev_tickets_own / dev_tickets_admin_write RLS policies on support_tickets.
-- ------------------------------------------------------------
create or replace function public.mark_ticket_resolved(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  update public.support_tickets
  set status = 'resolved', resolved_at = now(), updated_at = now()
  where id = p_ticket_id
    and (
      user_id = v_uid
      or public.has_role(v_uid, 'administrator')
      or public.has_role(v_uid, 'super_administrator')
    );

  if not found then
    raise exception 'ticket not found' using errcode = 'P0001';
  end if;
end $$;

revoke all on function public.mark_ticket_resolved(uuid) from public, anon;
grant execute on function public.mark_ticket_resolved(uuid) to authenticated, service_role;

-- ------------------------------------------------------------
-- acquire_venue_hold: unlike its sibling acquire_booking_hold, this never
-- validated that p_user_id matched the caller, and EXECUTE was still granted
-- to PUBLIC/anon -- any unauthenticated caller could create a booking hold
-- and a draft "held" booking under an arbitrary victim's user id. Add the
-- same auth.uid() = p_user_id guard acquire_booking_hold already has.
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
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'authenticated user mismatch' using errcode = '42501';
  end if;

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

revoke all on function public.acquire_venue_hold(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) from public, anon;
grant execute on function public.acquire_venue_hold(uuid, uuid, date, uuid, uuid, numeric, numeric, numeric, integer) to authenticated, service_role;

-- ------------------------------------------------------------
-- release_venue_hold: filtered on user_id = p_user_id but never checked that
-- p_user_id was actually the caller, and EXECUTE was still granted to
-- PUBLIC/anon -- a caller who knew (or guessed) another user's id and a hold
-- id could release/cancel that user's active hold and booking. Require
-- p_user_id to match the authenticated caller, same as acquire_venue_hold.
-- ------------------------------------------------------------
create or replace function public.release_venue_hold(p_hold_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'authenticated user mismatch' using errcode = '42501';
  end if;

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

revoke all on function public.release_venue_hold(uuid, uuid) from public, anon;
grant execute on function public.release_venue_hold(uuid, uuid) to authenticated, service_role;

-- ------------------------------------------------------------
-- my_enrolled_batches: returned any user's enrolled course batches for an
-- arbitrary p_user_id with no auth check, and EXECUTE was still granted to
-- PUBLIC/anon -- unauthenticated callers could enumerate another user's
-- course enrollments. Require p_user_id to match the caller; a mismatched
-- or unauthenticated call now returns an empty result set rather than an
-- error, consistent with this being a read-only lookup.
-- ------------------------------------------------------------
create or replace function public.my_enrolled_batches(p_user_id uuid)
returns table(batch_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select e.batch_id
  from public.course_enrollments e
  where e.user_id = p_user_id
    and e.status = 'enrolled'
    and p_user_id = auth.uid();
$$;

revoke all on function public.my_enrolled_batches(uuid) from public, anon;
grant execute on function public.my_enrolled_batches(uuid) to authenticated, service_role;

-- ------------------------------------------------------------
-- register_webhook_event: writes into public.webhook_events (locked to
-- clients by the webhook_events_no_client_access RLS policy, but security
-- definer bypasses that). EXECUTE was still granted to PUBLIC/anon/
-- authenticated even though the only real caller is the razorpay-webhook
-- edge function, which authenticates with the service role key. Leaving
-- this open lets anyone pre-insert a real provider's future event_id, which
-- the on-conflict-do-nothing dedupe would then silently treat the genuine
-- webhook delivery as a duplicate. Restrict execution to service_role.
-- ------------------------------------------------------------
revoke all on function public.register_webhook_event(text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.register_webhook_event(text, text, text, jsonb) to service_role;

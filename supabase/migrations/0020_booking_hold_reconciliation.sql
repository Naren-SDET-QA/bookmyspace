-- BookMySpace — Migration 0020: stale hold reconciliation hardening
-- Keeps the existing function signatures and RLS contracts unchanged.

-- Expiring a hold must also release any draft booking tied to it. Otherwise
-- the bookings_no_overlap constraint can leave inventory blocked forever.
create or replace function public.expire_stale_holds()
returns integer
language plpgsql
as $$
declare
  v_expired integer := 0;
begin
  update public.booking_holds
  set status = 'expired'
  where status = 'active' and expires_at < now();
  get diagnostics v_expired = row_count;

  update public.bookings b
  set status = 'cancelled', cancelled_at = now(), updated_at = now()
  from public.booking_holds h
  where b.hold_id = h.id
    and b.status in ('held', 'pending')
    and h.status = 'expired';

  return v_expired;
end $$;

-- Payment confirmation is only valid while the linked hold is still live.
-- Repeated webhook delivery remains idempotent for already-confirmed rows.
create or replace function public.confirm_booking(
  p_booking_id uuid,
  p_payment_ref text
)
returns void
language plpgsql
security definer
as $$
declare
  v_hold_id uuid;
begin
  if exists (
    select 1 from public.bookings
    where id = p_booking_id and status = 'confirmed'
  ) then
    return;
  end if;

  select hold_id into v_hold_id
  from public.bookings
  where id = p_booking_id and status = 'pending';

  if not found then
    raise exception 'booking is not pending';
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
  where id = p_booking_id and status = 'pending';
end $$;

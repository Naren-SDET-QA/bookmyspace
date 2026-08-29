-- ============================================================
-- Phase 17: Promo codes — server-side validation & application.
--
-- SCHEMA GAP ANALYSIS (per the read-only inspection requested before
-- writing this migration):
--   * `public.coupons` and `public.booking_coupons` already exist
--     (migration 0006) with exactly the fields a promo-code feature
--     needs: discount_type ('percentage'|'fixed'), discount_value,
--     max_discount_amount, min_booking_amount, max_uses,
--     max_uses_per_user, starts_at/ends_at, is_active.
--   * `public.bookings` already has amount, tax_amount,
--     discount_amount and total_amount columns (migration 0003).
--   * Neither the Flutter app nor any Edge Function references
--     coupons/booking_coupons anywhere (grepped clean) — there is
--     currently ZERO code path that validates or applies a coupon.
--   * `booking_coupons` has row level security enabled but NO
--     policies at all (grepped clean), so no client role can read or
--     write it directly today — by construction it can only be
--     touched through a SECURITY DEFINER function, which matches
--     this codebase's existing pattern for atomic, trust-sensitive
--     writes (acquire_booking_hold, owner_decide_booking).
--   * There is no schema gap: no new table/column is required. The
--     actual gap is the missing server-side validate/apply logic,
--     so this migration adds two SECURITY DEFINER functions plus
--     one defensive constraint (see below) — nothing else.
--   * This table is unrelated to `public.promotions` (added
--     2026-08-26): that is a display/banner system for the home
--     screen ("this table does not replace coupons" — its own
--     comment) and its `discounts_enabled` capability flag is off.
--     Promo-code pricing logic belongs on `coupons`/`booking_coupons`
--     only, so nothing there is touched.
--
-- Defensive addition: `booking_coupons` had no uniqueness constraint
-- on booking_id, so nothing stopped two coupon rows (and a doubled
-- discount) from ever being attached to the same booking. The apply
-- function below already enforces "one coupon per booking" by
-- deleting any prior row before inserting the new one, but the
-- constraint makes that invariant hold at the database level too.
-- ------------------------------------------------------------
alter table public.booking_coupons
  add constraint booking_coupons_booking_id_unique unique (booking_id);

create index if not exists idx_booking_coupons_coupon
  on public.booking_coupons(coupon_id);

-- ------------------------------------------------------------
-- apply_booking_coupon: the authoritative apply step. Runs against a
-- booking the caller owns, still in 'pending' status (i.e. after the
-- booking row exists, before payment is created). Recomputes the
-- discount from scratch server-side — the amount always comes from
-- the booking row, never from the caller — then persists it onto the
-- booking and records the redemption. Idempotent for a retry with
-- the SAME code (returns the existing result without re-counting
-- usage); a call with a DIFFERENT code atomically replaces the prior
-- one.
-- ------------------------------------------------------------
create or replace function public.apply_booking_coupon(
  p_booking_id uuid,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  b public.bookings;
  c public.coupons;
  existing public.booking_coupons;
  v_base numeric(12,2);
  v_discount numeric(12,2);
  v_total numeric(12,2);
  v_uses integer;
  v_user_uses integer;
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  select * into b from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;
  if b.status <> 'pending' then
    raise exception 'invalid_booking_state' using errcode = '55000';
  end if;

  select * into c from public.coupons
    where upper(code) = upper(trim(coalesce(p_code, '')));
  if not found then
    raise exception 'coupon_not_found' using errcode = 'P0002';
  end if;

  -- Idempotent retry: the same coupon is already applied to this
  -- booking — return the current state without re-validating usage
  -- limits again (a retry must never burn a second redemption).
  select * into existing from public.booking_coupons where booking_id = b.id;
  if found and existing.coupon_id = c.id then
    return jsonb_build_object(
      'applied', true,
      'coupon_id', c.id,
      'code', c.code,
      'discount_amount', existing.discount_amount,
      'base_amount', b.amount + b.tax_amount,
      'total_amount', b.total_amount
    );
  end if;

  if not c.is_active then
    raise exception 'coupon_inactive' using errcode = '55000';
  end if;
  if c.starts_at is not null and c.starts_at > now() then
    raise exception 'coupon_not_started' using errcode = '55000';
  end if;
  if c.ends_at is not null and c.ends_at <= now() then
    raise exception 'coupon_expired' using errcode = '55000';
  end if;

  v_base := b.amount + b.tax_amount;
  if coalesce(c.min_booking_amount, 0) > v_base then
    raise exception 'coupon_min_amount_not_met' using errcode = '55000';
  end if;

  if c.max_uses is not null then
    select count(*) into v_uses from public.booking_coupons where coupon_id = c.id;
    if v_uses >= c.max_uses then
      raise exception 'coupon_usage_limit_reached' using errcode = '55000';
    end if;
  end if;
  if c.max_uses_per_user is not null then
    select count(*) into v_user_uses
      from public.booking_coupons bc
      join public.bookings ob on ob.id = bc.booking_id
      where bc.coupon_id = c.id and ob.user_id = auth.uid();
    if v_user_uses >= c.max_uses_per_user then
      raise exception 'coupon_already_used_by_user' using errcode = '55000';
    end if;
  end if;

  v_discount := case c.discount_type
    when 'percentage' then round(v_base * c.discount_value / 100, 2)
    else c.discount_value
  end;
  if c.max_discount_amount is not null then
    v_discount := least(v_discount, c.max_discount_amount);
  end if;
  v_discount := greatest(least(v_discount, v_base), 0);
  v_total := v_base - v_discount;

  -- Replacing a different, previously-applied coupon: drop it first
  -- so at most one redemption row (and one discount) ever attaches
  -- to this booking.
  delete from public.booking_coupons where booking_id = b.id;

  insert into public.booking_coupons (booking_id, coupon_id, discount_amount)
    values (b.id, c.id, v_discount);

  update public.bookings
    set discount_amount = v_discount, total_amount = v_total, updated_at = now()
    where id = b.id and status = 'pending';

  return jsonb_build_object(
    'applied', true,
    'coupon_id', c.id,
    'code', c.code,
    'discount_amount', v_discount,
    'base_amount', v_base,
    'total_amount', v_total
  );
end;
$$;

-- ------------------------------------------------------------
-- remove_booking_coupon: clears a previously-applied coupon while
-- the booking is still 'pending', restoring the undiscounted total.
-- ------------------------------------------------------------
create or replace function public.remove_booking_coupon(
  p_booking_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  b public.bookings;
begin
  if auth.uid() is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  select * into b from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0002';
  end if;
  if b.user_id is distinct from auth.uid() then
    raise exception 'not_booking_owner' using errcode = '42501';
  end if;
  if b.status <> 'pending' then
    raise exception 'invalid_booking_state' using errcode = '55000';
  end if;

  delete from public.booking_coupons where booking_id = b.id;

  update public.bookings
    set discount_amount = 0, total_amount = b.amount + b.tax_amount, updated_at = now()
    where id = b.id and status = 'pending';

  return jsonb_build_object(
    'removed', true,
    'booking_id', b.id,
    'total_amount', b.amount + b.tax_amount
  );
end;
$$;

revoke all on function public.apply_booking_coupon(uuid, text) from public, anon;
revoke all on function public.remove_booking_coupon(uuid) from public, anon;
grant execute on function public.apply_booking_coupon(uuid, text) to authenticated, service_role;
grant execute on function public.remove_booking_coupon(uuid) to authenticated, service_role;

-- ------------------------------------------------------------
-- Dev-only fixtures for manual negative-path testing (expired,
-- inactive, minimum-amount, global usage-limit). Additive, same
-- pattern as the 0007 demo coupons; safe to leave in a dev/local
-- database. Does not touch WELCOME10/FESTIVE500.
-- ------------------------------------------------------------
insert into public.coupons
  (code, description, discount_type, discount_value, max_discount_amount, min_booking_amount, max_uses, max_uses_per_user, starts_at, ends_at, is_active)
values
  ('EXPIRED_TEST', 'Dev fixture: already expired', 'fixed', 100, null, 0, null, 1, now() - interval '30 days', now() - interval '1 day', true),
  ('INACTIVE_TEST', 'Dev fixture: deactivated coupon', 'percentage', 10, null, 0, null, 1, null, null, false),
  ('MIN5000_TEST', 'Dev fixture: requires a 5000 minimum booking', 'fixed', 200, null, 5000, null, 1, null, now() + interval '90 days', true),
  ('ONEUSE_TEST', 'Dev fixture: single global redemption', 'fixed', 50, null, 0, 1, 1, null, now() + interval '90 days', true)
on conflict (code) do nothing;

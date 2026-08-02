-- ============================================================
-- BookMySpace — Migration 0003: Availability, Slots, Booking
-- Holds, Bookings
--
-- Double-booking prevention is enforced at the DATABASE level:
--   * Exclusion constraint on bookings (date + time range overlap)
--   * Atomic hold creation with advisory lock
--   * Idempotency keys
--   * Automatic hold expiry via scheduled job
-- ============================================================

-- ------------------------------------------------------------
-- Extensions
-- ------------------------------------------------------------
create extension if not exists "btree_gist";

create table public.time_slots (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  label text not null,
  start_time time not null,
  end_time time not null,
  price_amount numeric(12,2) not null check (price_amount >= 0),
  is_active boolean not null default true,
  unique (venue_id, start_time, end_time)
);

create table public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  day_of_week smallint check (day_of_week between 0 and 6),
  start_date date,
  end_date date,
  price_multiplier numeric(4,2) not null default 1.00 check (price_multiplier > 0),
  is_seasonal boolean not null default false,
  note text,
  created_at timestamptz not null default now()
);

-- Blocked dates (owner unavailable dates e.g. maintenance).
create table public.venue_blocked_dates (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  blocked_date date not null,
  reason text,
  unique (venue_id, blocked_date)
);

-- ------------------------------------------------------------
-- BOOKING HOLDS (temporary reservations before payment)
-- ------------------------------------------------------------
create table public.booking_holds (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null,
  venue_id uuid not null references public.venues(id) on delete cascade,
  slot_id uuid not null references public.time_slots(id),
  book_date date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  price_amount numeric(12,2) not null check (price_amount >= 0),
  expires_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'confirmed', 'expired', 'released')),
  created_at timestamptz not null default now(),
  unique (idempotency_key)
);

-- ------------------------------------------------------------
-- BOOKINGS
-- ------------------------------------------------------------
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_ref text unique not null,
  user_id uuid not null references auth.users(id) on delete restrict,
  venue_id uuid not null references public.venues(id) on delete restrict,
  slot_id uuid not null references public.time_slots(id),
  book_date date not null,
  start_time time not null,
  end_time time not null,
  hold_id uuid references public.booking_holds(id),
  status public.booking_status not null default 'pending',
  quantity integer not null default 1 check (quantity > 0),
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'INR',
  tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(12,2) not null check (total_amount >= 0),
  cancellation_policy jsonb,
  metadata jsonb,
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- The key constraint: no two CONFIRMED/pending bookings may overlap
  -- the same venue, same date, same time range.
  -- tsrange (no tz) keeps the index expression IMMUTABLE and is correct
  -- for local-time venue bookings.
  constraint bookings_no_overlap exclude using gist (
    venue_id with =,
    book_date with =,
    tsrange(
      book_date + start_time,
      book_date + end_time,
      '[)'
    ) with &&
  ) where (status in ('held', 'pending', 'confirmed', 'completed'))
);

create index idx_bookings_user on public.bookings(user_id);
create index idx_bookings_venue_date on public.bookings(venue_id, book_date);
create index idx_bookings_status on public.bookings(status);
create index idx_holds_expiry on public.booking_holds(expires_at) where status = 'active';
create index idx_holds_venue_slot on public.booking_holds(venue_id, slot_id, book_date);

create trigger trg_bookings_updated_at before update on public.bookings
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- ATOMIC SLOT-LOCK ACQUISITION (double-booking prevention)
--
-- 1. Takes a session-level advisory lock scoped to (venue, date).
-- 2. Checks for overlapping active holds / confirmed bookings.
-- 3. Atomically inserts the hold.
-- 4. Returns the hold (or raises an error when occupied).
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

-- ------------------------------------------------------------
-- HOLD EXPIRY (scheduled reconciliation)
-- Marks expired holds 'expired' so slots free up. Safe to run repeatedly.
-- ------------------------------------------------------------
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
  return v_expired;
end $$;

-- ------------------------------------------------------------
-- CONFIRM BOOKING (called after webhook-verified payment)
-- ------------------------------------------------------------
create or replace function public.confirm_booking(
  p_booking_id uuid,
  p_payment_ref text
)
returns void
language plpgsql
security definer
as $$
begin
  update public.bookings
  set status = 'confirmed', confirmed_at = now(), metadata =
      coalesce(metadata, '{}'::jsonb) || jsonb_build_object('payment_ref', p_payment_ref)
  where id = p_booking_id and status = 'pending';
end $$;

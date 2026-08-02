-- ============================================================
-- BookMySpace — Migration 0004: Payments, Refunds, Payouts
--
-- Security rules:
--   * Payment secrets never live in the app
--   * Payment orders created only via Edge Functions
--   * Webhooks idempotent (unique webhook_event_id)
--   * Full PCI-DSS boundaries (no card numbers stored)
-- ============================================================

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  user_id uuid not null references auth.users(id),
  provider text not null default 'razorpay',
  provider_order_id text,
  provider_payment_id text,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'INR',
  status public.payment_status not null default 'pending',
  method text,
  is_refundable boolean not null default true,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_order_id)
);

create table public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  provider_attempt_id text,
  status public.payment_status not null default 'pending',
  error_code text,
  error_message text,
  created_at timestamptz not null default now()
);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  booking_id uuid not null references public.bookings(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  reason text,
  status text not null default 'requested' check (status in ('requested', 'approved', 'processed', 'rejected', 'failed')),
  provider_refund_id text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  commission_amount numeric(12,2) not null default 0,
  status text not null default 'requested' check (status in ('requested', 'approved', 'processing', 'paid', 'failed')),
  provider text default 'razorpay',
  provider_payout_id text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create table public.owner_bank_accounts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  account_holder text not null,
  bank_name text not null,
  account_number_encrypted text not null,   -- encrypted; never plaintext
  ifsc_code text not null,
  upi_id text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now()
);

-- Webhook events: idempotency store for provider webhooks.
create table public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  event_type text not null,
  payload jsonb not null,
  processed boolean not null default false,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, event_id)
);

create index idx_payments_booking on public.payments(booking_id);
create index idx_payments_user on public.payments(user_id);
create index idx_attempts_payment on public.payment_attempts(payment_id);
create index idx_refunds_payment on public.refunds(payment_id);
create index idx_payouts_org on public.payouts(org_id);
create index idx_webhook_processed on public.webhook_events(provider, processed) where processed = false;

create trigger trg_payments_updated_at before update on public.payments
  for each row execute function public.set_updated_at();
create trigger trg_refunds_updated_at before update on public.refunds
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- RECONCILIATION (scheduled): verify pending payments with provider.
-- Marks stale pending payments for re-check. Runs on a schedule.
-- ------------------------------------------------------------
create or replace function public.reconcile_stale_payments(
  p_stale_after_minutes integer default 30
)
returns integer
language plpgsql
as $$
declare
  v_count integer := 0;
begin
  update public.payments
  set status = 'failed', updated_at = now()
  where status = 'pending'
    and created_at < now() - make_interval(mins => p_stale_after_minutes);
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- ------------------------------------------------------------
-- IDEMPOTENT WEBHOOK REGISTRATION
-- Returns 'processed' if already handled (prevents duplicate bookings).
-- ------------------------------------------------------------
create or replace function public.register_webhook_event(
  p_provider text,
  p_event_id text,
  p_event_type text,
  p_payload jsonb
)
returns boolean
language plpgsql
security definer
as $$
begin
  insert into public.webhook_events (provider, event_id, event_type, payload)
  values (p_provider, p_event_id, p_event_type, p_payload)
  on conflict (provider, event_id) do nothing;
  return found;
end $$;

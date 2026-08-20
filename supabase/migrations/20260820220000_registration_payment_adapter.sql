-- Generic registration payment bridge over the existing Razorpay provider.
-- Booking payments remain unchanged.
alter table public.module_feature_configs
  add column if not exists payment_timing text not null default 'payment_not_required'
  check (payment_timing in ('payment_required_before_submission','payment_required_before_approval','payment_required_before_confirmation','payment_not_required'));

create table if not exists public.module_registration_payments (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.module_form_submissions(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  module_key text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  refundable boolean not null default true,
  idempotency_key uuid not null unique,
  provider text not null default 'razorpay',
  provider_order_id text unique,
  provider_payment_id text,
  status text not null default 'pending' check (status in ('not_required','pending','processing','paid','failed','refunded','partially_refunded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (submission_id)
);
create index if not exists module_registration_payments_user_idx on public.module_registration_payments(user_id, created_at desc);
create unique index if not exists module_registration_payments_pending_idx
  on public.module_registration_payments(submission_id) where status in ('pending','processing');
alter table public.module_registration_payments enable row level security;
grant select on public.module_registration_payments to authenticated;
create policy module_registration_payments_customer_read on public.module_registration_payments
  for select to authenticated using (user_id=(select auth.uid()));
create policy module_registration_payments_owner_read on public.module_registration_payments
  for select to authenticated using (exists (
    select 1 from public.module_form_submissions s join public.venues v on v.id=s.venue_id
    join public.organizations o on o.id=v.org_id
    where s.id=submission_id and o.owner_user_id=(select auth.uid())
  ));
create policy module_registration_payments_admin_read on public.module_registration_payments
  for select to authenticated using (public.is_platform_admin((select auth.uid())));
revoke all on public.module_registration_payments from anon;

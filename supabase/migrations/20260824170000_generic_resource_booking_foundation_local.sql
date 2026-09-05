-- Local-only Phase 6.7 foundation.
-- Existing slot bookings remain valid; resource bookings use resource_id.

create table if not exists public.bookable_resources (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null,
  venue_id uuid not null references public.venues(id) on delete cascade,
  category_id uuid references public.venue_categories(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  external_reference uuid,
  active boolean not null default true,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists bookable_resources_org_idx on public.bookable_resources(organization_id, active);
create index if not exists bookable_resources_venue_idx on public.bookable_resources(venue_id, active);
create index if not exists bookable_resources_category_idx on public.bookable_resources(category_id, active);
create index if not exists bookable_resources_type_idx on public.bookable_resources(resource_type, active);

alter table public.bookings
  add column if not exists resource_id uuid references public.bookable_resources(id) on delete restrict,
  add column if not exists resource_start_at timestamptz,
  add column if not exists resource_end_at timestamptz;

alter table public.booking_holds
  add column if not exists resource_id uuid references public.bookable_resources(id) on delete restrict,
  add column if not exists resource_start_at timestamptz,
  add column if not exists resource_end_at timestamptz;

alter table public.bookings alter column slot_id drop not null;
alter table public.bookings alter column start_time drop not null;
alter table public.bookings alter column end_time drop not null;
alter table public.booking_holds alter column slot_id drop not null;

alter table public.bookings drop constraint if exists bookings_slot_or_resource_ck;
alter table public.bookings add constraint bookings_slot_or_resource_ck
  check (slot_id is not null or resource_id is not null);
alter table public.bookings drop constraint if exists bookings_resource_window_ck;
alter table public.bookings add constraint bookings_resource_window_ck
  check (resource_id is null or (resource_start_at is not null and resource_end_at is not null and resource_end_at > resource_start_at));
alter table public.booking_holds drop constraint if exists booking_holds_slot_or_resource_ck;
alter table public.booking_holds add constraint booking_holds_slot_or_resource_ck
  check (slot_id is not null or resource_id is not null);
alter table public.booking_holds drop constraint if exists booking_holds_resource_window_ck;
alter table public.booking_holds add constraint booking_holds_resource_window_ck
  check (resource_id is null or (resource_start_at is not null and resource_end_at is not null and resource_end_at > resource_start_at));

create index if not exists bookings_resource_window_idx
  on public.bookings(resource_id, resource_start_at, resource_end_at)
  where resource_id is not null;
create index if not exists booking_holds_resource_window_idx
  on public.booking_holds(resource_id, resource_start_at, resource_end_at)
  where resource_id is not null;

alter table public.refunds add column if not exists idempotency_key uuid;
alter table public.refunds add column if not exists policy_snapshot jsonb;
alter table public.refunds add column if not exists cancellation_fee numeric(12,2) not null default 0 check (cancellation_fee >= 0);
alter table public.refunds add column if not exists refund_amount numeric(12,2) check (refund_amount >= 0);
alter table public.refunds add column if not exists provider_status text;
alter table public.refunds add column if not exists credit_note_reference text;
alter table public.refunds add column if not exists retry_count integer not null default 0 check (retry_count >= 0);
alter table public.refunds add column if not exists last_error text;
alter table public.refunds add column if not exists processed_at timestamptz;
create unique index if not exists refunds_idempotency_key_idx on public.refunds(idempotency_key) where idempotency_key is not null;

create table if not exists public.inventory_restorations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  resource_id uuid references public.bookable_resources(id) on delete restrict,
  restoration_key text not null unique,
  quantity integer not null check (quantity > 0),
  restored_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

alter table public.bookable_resources enable row level security;
alter table public.inventory_restorations enable row level security;
drop policy if exists bookable_resources_public_read on public.bookable_resources;
create policy bookable_resources_public_read on public.bookable_resources
  for select to anon, authenticated using (active = true);
drop policy if exists inventory_restorations_owner_read on public.inventory_restorations;
create policy inventory_restorations_owner_read on public.inventory_restorations
  for select to authenticated using (exists (
    select 1 from public.bookings b where b.id = booking_id and b.user_id = auth.uid()
  ));

revoke all on public.bookable_resources, public.inventory_restorations from anon;
grant select on public.bookable_resources to anon, authenticated;
grant select on public.inventory_restorations to authenticated;

-- ============================================================
-- BookMySpace — Migration 0005: Row Level Security Policies
--
-- Principle: RLS is enforced on every table. Policies use
-- server-side role checks (JWT via auth.uid()) only — never
-- trust client-side flags.
-- ============================================================

-- ------------------------------------------------------------
-- Enable RLS on all tables
-- ------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.organizations enable row level security;
alter table public.venue_categories enable row level security;
alter table public.venues enable row level security;
alter table public.venue_images enable row level security;
alter table public.venue_facilities enable row level security;
alter table public.venue_operating_hours enable row level security;
alter table public.time_slots enable row level security;
alter table public.pricing_rules enable row level security;
alter table public.venue_blocked_dates enable row level security;
alter table public.booking_holds enable row level security;
alter table public.bookings enable row level security;
alter table public.payments enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.owner_bank_accounts enable row level security;
alter table public.webhook_events enable row level security;

-- ------------------------------------------------------------
-- Helper: service role bypass (must be revokeable in prod review)
-- ------------------------------------------------------------
-- The service_role bypasses RLS by design. Webhook handlers run with
-- the service role only inside Edge Functions behind auth checks.

-- ------------------------------------------------------------
-- PROFILES
-- ------------------------------------------------------------
create policy "profiles_select_own_or_admin" on public.profiles
  for select using (
    auth.uid() = id
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
    or public.has_role(auth.uid(), 'support_agent')
  );

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- ------------------------------------------------------------
-- USER ROLES
-- ------------------------------------------------------------
create policy "user_roles_read_own_or_admin" on public.user_roles
  for select using (
    auth.uid() = user_id
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

-- Only admins grant roles.
create policy "user_roles_admin_write" on public.user_roles
  for all using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

-- ------------------------------------------------------------
-- ORGANIZATIONS
-- ------------------------------------------------------------
create policy "organizations_select_owner_or_admin" on public.organizations
  for select using (
    auth.uid() = owner_user_id
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

create policy "organizations_insert_owner" on public.organizations
  for insert with check (auth.uid() = owner_user_id);

create policy "organizations_update_owner" on public.organizations
  for update using (auth.uid() = owner_user_id)
  with check (auth.uid() = owner_user_id);

-- ------------------------------------------------------------
-- VENUE CATEGORIES (public catalogue)
-- ------------------------------------------------------------
create policy "categories_public_read" on public.venue_categories
  for select using (true);

-- ------------------------------------------------------------
-- VENUES
-- ------------------------------------------------------------
create policy "venues_public_read" on public.venues
  for select using (is_active and deleted_at is null);

create policy "venues_owner_write" on public.venues
  for all using (
    exists (
      select 1 from public.organizations o
      where o.id = org_id and o.owner_user_id = auth.uid() and o.deleted_at is null
    )
  )
  with check (
    exists (
      select 1 from public.organizations o
      where o.id = org_id and o.owner_user_id = auth.uid() and o.deleted_at is null
    )
  );

-- ------------------------------------------------------------
-- VENUE IMAGES / FACILITIES / HOURS (owner-managed, public read)
-- ------------------------------------------------------------
create policy "venue_images_public_read" on public.venue_images
  for select using (true);
create policy "venue_images_owner_write" on public.venue_images
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

create policy "venue_facilities_public_read" on public.venue_facilities
  for select using (true);
create policy "venue_facilities_owner_write" on public.venue_facilities
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

create policy "venue_hours_public_read" on public.venue_operating_hours
  for select using (true);
create policy "venue_hours_owner_write" on public.venue_operating_hours
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- TIME SLOTS / PRICING / BLOCKED DATES (public availability read)
-- ------------------------------------------------------------
create policy "slots_public_read" on public.time_slots
  for select using (is_active);
create policy "slots_owner_write" on public.time_slots
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

create policy "pricing_public_read" on public.pricing_rules
  for select using (true);
create policy "pricing_owner_write" on public.pricing_rules
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

create policy "blocked_dates_public_read" on public.venue_blocked_dates
  for select using (true);
create policy "blocked_dates_owner_write" on public.venue_blocked_dates
  for all using (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- BOOKING HOLDS (owner of the hold only)
-- ------------------------------------------------------------
create policy "holds_owner_read" on public.booking_holds
  for select using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- BOOKINGS (user or venue owner)
-- ------------------------------------------------------------
create policy "bookings_user_read" on public.bookings
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.venues v
      join public.organizations o on o.id = v.org_id
      where v.id = venue_id and o.owner_user_id = auth.uid()
    )
  );

create policy "bookings_user_insert" on public.bookings
  for insert with check (auth.uid() = user_id);

-- Booking confirmation/cancel flows run through Edge Functions with the
-- service role; direct updates by end users are intentionally not allowed.
create policy "bookings_user_update_own" on public.bookings
  for update using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status in ('cancelled', 'pending'));

-- ------------------------------------------------------------
-- PAYMENTS (user and venue owner read; writes only via service role)
-- ------------------------------------------------------------
create policy "payments_user_read" on public.payments
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.bookings b
      join public.venues v on v.id = b.venue_id
      join public.organizations o on o.id = v.org_id
      where b.id = public.payments.booking_id and o.owner_user_id = auth.uid()
    )
  );

create policy "attempts_user_read" on public.payment_attempts
  for select using (
    exists (
      select 1 from public.payments p
      where p.id = payment_id and p.user_id = auth.uid()
    )
  );

create policy "refunds_user_read" on public.refunds
  for select using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id and b.user_id = auth.uid()
    )
  );

create policy "payouts_owner_read" on public.payouts
  for select using (
    exists (
      select 1 from public.organizations o
      where o.id = org_id and o.owner_user_id = auth.uid()
    )
  );

create policy "bank_accounts_owner_write" on public.owner_bank_accounts
  for all using (
    exists (
      select 1 from public.organizations o
      where o.id = org_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.organizations o
      where o.id = org_id and o.owner_user_id = auth.uid()
    )
  );

-- Webhook events are internal; never exposed to app clients.
create policy "webhook_events_no_client_access" on public.webhook_events
  for all using (false);

-- ============================================================
-- BookMySpace — Migration 0020: Institute Listing Plans and Listings
-- ============================================================

-- ------------------------------------------------------------
-- INSTITUTE LISTING PLANS
-- ------------------------------------------------------------
create table public.institute_listing_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(12,2) not null check (price >= 0),
  duration_in_days integer not null check (duration_in_days > 0),
  features text[], -- array of feature descriptions
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- INSTITUTE LISTINGS
-- ------------------------------------------------------------
create table public.institute_listings (
  id uuid primary key default gen_random_uuid(),
  institute_id uuid not null references public.institutes(id) on delete cascade,
  plan_id uuid not null references public.institute_listing_plans(id),
  payment_id uuid references public.payments(id), -- nullable until payment is made
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ends_after_starts check (ends_at > starts_at)
);

-- ------------------------------------------------------------
-- RLS for institute_listing_plans
-- ------------------------------------------------------------
alter table public.institute_listing_plans enable row level security;

create policy "institute_listing_plans_public_read" on public.institute_listing_plans
  for select using (is_active);

create policy "institute_listing_plans_admin_write" on public.institute_listing_plans
  for all using (
    public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
  );

-- ------------------------------------------------------------
-- RLS for institute_listings
-- ------------------------------------------------------------
alter table public.institute_listings enable row level security;

create policy "institute_listings_public_read" on public.institute_listings
  for select using (is_active and ends_at > now());

create policy "institute_listings_owner_write" on public.institute_listings
  for all using (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  );

create policy "institute_listings_owner_read" on public.institute_listings
  for select using (
    exists (
      select 1 from public.institutes i
      join public.organizations o on o.id = i.org_id
      where i.id = institute_id and o.owner_user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- INSERT DEFAULT PLANS
-- ------------------------------------------------------------
insert into public.institute_listing_plans (name, description, price, duration_in_days, features, is_active)
values
  ('Basic', 'Basic institute listing', 999.00, 30, ARRAY['Name, description, logo', 'Contact details', 'Map location'], true),
  ('Standard', 'Standard institute listing with featured placement', 1999.00, 30, ARRAY['Basic features', 'Featured in search results', 'Priority listing'], true),
  ('Premium', 'Premium institute listing with highlights', 2999.00, 30, ARRAY['Standard features', 'Highlighted banner', 'Analytics reports'], true);
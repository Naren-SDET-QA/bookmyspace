-- ============================================================
-- BookMySpace — Migration 0001: Users, Profiles, Roles, Orgs
-- Role model: PostgreSQL roles + JWT claims + RLS policies
-- ============================================================

-- ------------------------------------------------------------
-- Extensions
-- ------------------------------------------------------------
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";
create extension if not exists "postgis";

-- ------------------------------------------------------------
-- ENUMS
-- ------------------------------------------------------------
create type public.user_role as enum (
  'customer',
  'venue_owner',
  'institute_owner',
  'event_organizer',
  'support_agent',
  'administrator',
  'super_administrator'
);

create type public.org_type as enum (
  'venue_owner',
  'institute_owner',
  'event_organizer'
);

create type public.verification_status as enum (
  'pending',
  'submitted',
  'approved',
  'rejected'
);

create type public.booking_status as enum (
  'held',
  'pending',
  'confirmed',
  'completed',
  'cancelled',
  'refunded',
  'no_show'
);

create type public.payment_status as enum (
  'pending',
  'authorized',
  'captured',
  'failed',
  'refunded',
  'partially_refunded'
);

-- ------------------------------------------------------------
-- PROFILES (extends auth.users via FK)
-- ------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text unique,
  email text unique,
  avatar_url text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.user_role not null default 'customer',
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, role)
);

-- ------------------------------------------------------------
-- ORGANIZATIONS (owner business entity)
-- ------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  org_type public.org_type not null,
  name text not null,
  legal_name text,
  gstin text,
  pan text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country text not null default 'IN',
  latitude double precision,
  longitude double precision,
  identity_verification public.verification_status not null default 'pending',
  business_verification public.verification_status not null default 'pending',
  verification_docs jsonb,
  commission_rate numeric(5,2) not null default 10.00 check (commission_rate >= 0 and commission_rate <= 100),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Owner belongs to an organization (for venue ownership checks).
alter table public.profiles
  add column default_org_id uuid references public.organizations(id);

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------
create index idx_profiles_phone on public.profiles(phone) where deleted_at is null;
create index idx_user_roles_user on public.user_roles(user_id);
create index idx_orgs_owner on public.organizations(owner_user_id);
create index idx_orgs_type on public.organizations(org_type);

-- ------------------------------------------------------------
-- TRIGGERS
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_organizations_updated_at before update on public.organizations
  for each row execute function public.set_updated_at();

-- Auto-create a profile row and 'customer' role when a user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.email,
    new.phone
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'customer')
  on conflict (user_id, role) do nothing;

  return new;
end $$;

create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: does a user hold a role?
create or replace function public.has_role(uid uuid, r public.user_role)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.user_roles
    where user_id = uid and role = r and revoked_at is null
  );
$$;

-- Helper: is the user the owner of an organization?
create or replace function public.is_org_owner(org_id uuid, uid uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.organizations
    where id = org_id and owner_user_id = uid and deleted_at is null
  );
$$;

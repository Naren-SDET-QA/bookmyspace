-- ============================================================
-- BookMySpace — Migration 0014: Owner Registration and Roles
--
-- Adds a dedicated owner profile separate from user auth and an owner-specific
-- role for fine-grained RLS. Owner registration bypasses the generic sign-up,
-- using email/password directly into an owner profile linked to an organization.
-- ============================================================

-- ------------------------------------------------------------
-- Owner profiles (link to auth.users via a dedicated owner_user_id)
-- ------------------------------------------------------------
create table public.owner_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  email text not null,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_owner_profiles_updated_at
  before update on public.owner_profiles
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- Owner role for RLS (owner_user_id must exist in owner_profiles)
-- ------------------------------------------------------------
create role owner;

-- Owner can read/write own rows and anything scoped to their organization.
-- This role will be used in RLS policies.

create policy "owner_profiles_own" on public.owner_profiles
  for all
  using (public.get_owner_user_id() is not null)
  with check (public.get_owner_user_id() is not null);

-- ------------------------------------------------------------
-- Extend organizations with primary owner
-- ------------------------------------------------------------
-- Add an owner_user_id column to organizations, pointing to owner_profiles.id
-- Keep org-level policies intact.
alter table public.organizations
  add column owner_user_id uuid references public.owner_profiles(id);

-- RLS policy so only the primary owner can write org details.
create policy "organizations_owner_write" on public.organizations
  for all
  using (public.get_owner_user_id() = owner_user_id)
  with check (public.get_owner_user_id() = owner_user_id);

-- ------------------------------------------------------------
-- Get current owner user id (null if not an owner)
-- ------------------------------------------------------------
create or replace function public.get_owner_user_id()
returns uuid
language sql
stable
as $$
  select p.user_id
  from public.owner_profiles p
  where p.user_id = (select auth.uid())
$$;

-- ------------------------------------------------------------
-- Owner registration function (email + password)
-- ------------------------------------------------------------
create or replace function public.register_owner(
  p_email text,
  p_password text,
  p_name text
)
returns uuid
language plpgsql
as $$
declare
  v_owner_id uuid;
  v_user_id uuid;
begin
  -- Create auth user (simplified local signup — in production use auth.sign_up)
  insert into auth.users (id, email, raw_user_meta_data)
  values (gen_random_uuid(), p_email, jsonb_build_object('name', p_name))
  returning id into v_user_id;

  -- Link to owner profile
  insert into public.owner_profiles (user_id, email, name)
  values (v_user_id, p_email, p_name)
  returning id into v_owner_id;

  -- Create a corresponding organization (optional — can be added later)
  -- For now, just the owner profile exists.

  return v_owner_id;
end $$;

-- ------------------------------------------------------------
-- DEMO OWNER (owner@demo.com) for local dev
-- ------------------------------------------------------------
-- Ensure the demo owner exists in auth.users.
insert into auth.users (id, email, raw_user_meta_data)
values (
  '00000000-0000-0000-0000-000000000002',
  'owner@demo.com',
  jsonb_build_object('name', 'Demo Owner')
)
on conflict (id) do nothing;

-- Create owner profile for demo owner if missing.
insert into public.owner_profiles (user_id, email, name)
select id, email, raw_user_meta_data->>'name'
from auth.users
where email = 'owner@demo.com'
on conflict (user_id) do nothing;

-- Create a test organization owned by demo owner.
insert into public.organizations (id, owner_user_id, org_type, name)
select gen_random_uuid(), op.user_id, 'venue_owner', 'Demo Venues'
from public.owner_profiles op
where op.email = 'owner@demo.com'
on conflict do nothing;

-- ------------------------------------------------------------
-- RLS for owner profiles and organizations (owner role integration)
-- ------------------------------------------------------------
alter table public.owner_profiles enable row level security;
alter table public.organizations enable row level security;

create policy "owner_profiles_owner_read" on public.owner_profiles
  for select
  using (public.get_owner_user_id() is not null);

create policy "organizations_owner_read" on public.organizations
  for select
  using (public.get_owner_user_id() is not null);

create or replace function public.delete_owner_account(p_user_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_owner_id uuid;
begin
  -- Get owner profile id
  select id into v_owner_id
  from public.owner_profiles
  where user_id = p_user_id;

  if v_owner_id is not null then
    -- Delete owner profile
    delete from public.owner_profiles where id = v_owner_id;
    -- Note: auth.users deletion via admin API (handled by Edge Function)
  end if;
end $$;
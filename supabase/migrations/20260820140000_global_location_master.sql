-- BookMySpace global Location Master.
-- This migration is additive: legacy venue location columns and PostGIS remain
-- authoritative for backwards-compatible discovery while normalized location
-- associations are introduced gradually.

create table if not exists public.location_nodes (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.location_nodes(id),
  level text not null check (level in ('country', 'state_province', 'district_county', 'city_town', 'area_locality')),
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  name text not null check (length(trim(name)) > 0),
  normalized_name text not null check (length(trim(normalized_name)) > 0),
  official_code text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  timezone text,
  status text not null default 'active' check (status in ('pending', 'active', 'inactive', 'merged')),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  merged_into_id uuid references public.location_nodes(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (level = 'country' or parent_id is not null),
  check (level <> 'country' or parent_id is null),
  check ((status = 'merged') = (merged_into_id is not null))
);

create unique index if not exists location_nodes_active_sibling_name_idx
  on public.location_nodes (
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    level,
    normalized_name
  ) where status in ('pending', 'active');

create index if not exists location_nodes_parent_level_idx
  on public.location_nodes(parent_id, level, status);
create index if not exists location_nodes_country_level_idx
  on public.location_nodes(country_code, level, status);
create index if not exists location_nodes_name_idx
  on public.location_nodes using gin (to_tsvector('simple', name || ' ' || normalized_name));

create table if not exists public.location_aliases (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.location_nodes(id) on delete cascade,
  alias text not null check (length(trim(alias)) > 0),
  normalized_alias text not null check (length(trim(normalized_alias)) > 0),
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  unique (location_id, normalized_alias, locale)
);

create index if not exists location_aliases_lookup_idx
  on public.location_aliases(normalized_alias, locale);

create table if not exists public.location_suggestions (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid references auth.users(id),
  provider text not null,
  provider_reference text,
  raw_query text not null,
  suggested_name text not null,
  suggested_level text check (suggested_level in ('country', 'state_province', 'district_county', 'city_town', 'area_locality')),
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists location_suggestions_status_idx
  on public.location_suggestions(status, created_at desc);

create table if not exists public.location_change_history (
  id uuid primary key default gen_random_uuid(),
  location_id uuid references public.location_nodes(id),
  action text not null check (action in ('create', 'update', 'approve', 'deactivate', 'merge', 'restore')),
  changed_by uuid references auth.users(id),
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);

alter table public.venues
  add column if not exists location_node_id uuid references public.location_nodes(id);

create index if not exists venues_location_node_idx
  on public.venues(location_node_id)
  where deleted_at is null and is_active;

create or replace function public.set_location_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_location_nodes_updated_at on public.location_nodes;
create trigger trg_location_nodes_updated_at
before update on public.location_nodes
for each row execute function public.set_location_updated_at();

alter table public.location_nodes enable row level security;
alter table public.location_aliases enable row level security;
alter table public.location_suggestions enable row level security;
alter table public.location_change_history enable row level security;

drop policy if exists location_nodes_public_read on public.location_nodes;
create policy location_nodes_public_read on public.location_nodes
for select to anon, authenticated
using (status = 'active' and approved_at is not null);

drop policy if exists location_nodes_admin_manage on public.location_nodes;
create policy location_nodes_admin_manage on public.location_nodes
for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists location_aliases_public_read on public.location_aliases;
create policy location_aliases_public_read on public.location_aliases
for select to anon, authenticated
using (exists (
  select 1 from public.location_nodes n
  where n.id = location_id and n.status = 'active' and n.approved_at is not null
));

drop policy if exists location_aliases_admin_manage on public.location_aliases;
create policy location_aliases_admin_manage on public.location_aliases
for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists location_suggestions_submit on public.location_suggestions;
create policy location_suggestions_submit on public.location_suggestions
for insert to authenticated
with check (requested_by = auth.uid());

drop policy if exists location_suggestions_own_read on public.location_suggestions;
create policy location_suggestions_own_read on public.location_suggestions
for select to authenticated
using (requested_by = auth.uid());

drop policy if exists location_suggestions_admin_manage on public.location_suggestions;
create policy location_suggestions_admin_manage on public.location_suggestions
for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists location_history_admin_read on public.location_change_history;
create policy location_history_admin_read on public.location_change_history
for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

-- Approved DEV reference data only. It is safe to remove or replace before
-- production rollout; no venue rows are changed by this seed.
insert into public.location_nodes (level, country_code, name, normalized_name, timezone, status, approved_at)
values
  ('country', 'IN', 'India', 'india', 'Asia/Kolkata', 'active', now()),
  ('country', 'US', 'United States', 'united states', 'America/New_York', 'active', now()),
  ('country', 'GB', 'United Kingdom', 'united kingdom', 'Europe/London', 'active', now()),
  ('country', 'AE', 'United Arab Emirates', 'united arab emirates', 'Asia/Dubai', 'active', now()),
  ('country', 'SG', 'Singapore', 'singapore', 'Asia/Singapore', 'active', now()),
  ('country', 'AU', 'Australia', 'australia', 'Australia/Sydney', 'active', now())
on conflict do nothing;

insert into public.location_nodes (parent_id, level, country_code, name, normalized_name, timezone, status, approved_at)
select id, 'state_province', 'IN', 'Telangana', 'telangana', 'Asia/Kolkata', 'active', now()
from public.location_nodes where level = 'country' and country_code = 'IN'
on conflict do nothing;

insert into public.location_nodes (parent_id, level, country_code, name, normalized_name, timezone, status, approved_at)
select id, 'city_town', 'IN', 'Hyderabad', 'hyderabad', 'Asia/Kolkata', 'active', now()
from public.location_nodes where level = 'state_province' and normalized_name = 'telangana'
on conflict do nothing;

insert into public.location_nodes (parent_id, level, country_code, name, normalized_name, timezone, status, approved_at)
select id, 'area_locality', 'IN', 'Madhapur', 'madhapur', 'Asia/Kolkata', 'active', now()
from public.location_nodes where level = 'city_town' and normalized_name = 'hyderabad'
on conflict do nothing;

comment on table public.location_nodes is 'Authoritative approved BookMySpace global location hierarchy.';
comment on column public.venues.location_node_id is 'Nullable normalized location association; legacy text and PostGIS remain supported during migration.';

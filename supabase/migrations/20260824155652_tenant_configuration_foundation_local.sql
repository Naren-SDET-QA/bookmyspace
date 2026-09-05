-- Local-only tenant configuration foundation. Reuses organizations as tenants.
create table if not exists public.organization_configurations (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  branding jsonb not null default '{}'::jsonb,
  theme jsonb not null default '{}'::jsonb,
  language jsonb not null default '{}'::jsonb,
  features jsonb not null default '{}'::jsonb,
  booking jsonb not null default '{}'::jsonb,
  notifications jsonb not null default '{}'::jsonb,
  media jsonb not null default '{}'::jsonb,
  voice jsonb not null default '{}'::jsonb,
  categories jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_configurations_no_raw_secrets check (
    not (features ?| array['secret','password','token','api_key','access_token','credential'])
  )
);

create table if not exists public.organization_category_configurations (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid not null references public.venue_categories(id) on delete cascade,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organization_id, category_id),
  constraint organization_category_configurations_no_raw_secrets check (
    not (configuration ?| array['secret','password','token','api_key','access_token','credential'])
  )
);

create index if not exists organization_category_configurations_category_idx
  on public.organization_category_configurations(category_id);

alter table public.organization_configurations enable row level security;
alter table public.organization_category_configurations enable row level security;

drop policy if exists organization_configurations_read on public.organization_configurations;
create policy organization_configurations_read on public.organization_configurations
  for select to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );
drop policy if exists organization_configurations_write on public.organization_configurations;
create policy organization_configurations_write on public.organization_configurations
  for all to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

drop policy if exists organization_category_configurations_read on public.organization_category_configurations;
create policy organization_category_configurations_read on public.organization_category_configurations
  for select to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );
drop policy if exists organization_category_configurations_write on public.organization_category_configurations;
create policy organization_category_configurations_write on public.organization_category_configurations
  for all to authenticated
  using (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    exists (select 1 from public.organizations o where o.id = organization_id and o.owner_user_id = auth.uid())
    or public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

revoke all on public.organization_configurations, public.organization_category_configurations from anon;
grant select, insert, update, delete on public.organization_configurations, public.organization_category_configurations to authenticated;

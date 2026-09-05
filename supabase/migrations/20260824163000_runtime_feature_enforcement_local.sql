-- Local-only additive tenant binding for server-side feature enforcement.
alter table if exists public.integrations
  add column if not exists organization_id uuid references public.organizations(id) on delete cascade;

create index if not exists integrations_organization_idx
  on public.integrations(organization_id)
  where organization_id is not null;

comment on column public.integrations.organization_id is
  'Tenant scope for server-side runtime enforcement; NULL is retained for legacy platform integrations.';

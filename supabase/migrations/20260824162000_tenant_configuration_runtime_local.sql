-- Local-only runtime refresh metadata for Phase 6.5B.
-- This migration is additive and must not be applied to hosted DEV/production.
alter table if exists public.organization_configurations
  add column if not exists configuration_version bigint not null default 1;

create or replace function public.bump_organization_configuration_version()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.configuration_version = coalesce(old.configuration_version, 0) + 1;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists organization_configurations_version on public.organization_configurations;
create trigger organization_configurations_version
before update on public.organization_configurations
for each row execute function public.bump_organization_configuration_version();

grant execute on function public.bump_organization_configuration_version() to authenticated;

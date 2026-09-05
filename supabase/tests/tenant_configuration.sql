-- Read-only local contract checks for tenant configuration.
do $$
begin
  if to_regclass('public.organization_configurations') is null
     or to_regclass('public.organization_category_configurations') is null then
    raise exception 'tenant configuration tables missing';
  end if;
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'organization_configurations' and c.relrowsecurity
  ) then raise exception 'tenant configuration RLS missing'; end if;
  if exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public' and c.table_name in ('organization_configurations','organization_category_configurations')
      and c.column_name in ('secret','password','token','api_key','access_token','credential')
  ) then raise exception 'raw credential column found'; end if;
end $$;
select 'tenant configuration contract passed' as result;

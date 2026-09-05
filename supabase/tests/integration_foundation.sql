-- Read-only local contract checks for Slice 6.1.
-- Run against local Supabase after applying the migration.
do $$
declare
  table_name text;
  required_tables constant text[] := array[
    'integrations', 'integration_credentials', 'integration_actions',
    'integration_mappings', 'integration_events', 'integration_tools',
    'integration_logs'
  ];
begin
  foreach table_name in array required_tables loop
    if to_regclass('public.' || table_name) is null then
      raise exception 'Missing integration foundation table: %', table_name;
    end if;
  end loop;

  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'integration_credentials'
      and c.relrowsecurity
  ) then
    raise exception 'Credentials RLS is not enabled';
  end if;

  if exists (
    select 1 from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name like 'integration%'
      and c.column_name in ('secret', 'api_key', 'password', 'token')
  ) then
    raise exception 'Raw secret column found in integration foundation';
  end if;
end $$;

select 'integration foundation contract passed' as result;

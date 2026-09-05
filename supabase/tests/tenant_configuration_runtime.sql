-- Local SQL contract checks; read-only after migration application.
select configuration_version from public.organization_configurations limit 1;
select tgname from pg_trigger where tgname = 'organization_configurations_version';

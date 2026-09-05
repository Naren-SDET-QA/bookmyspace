do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='health_checks' and column_name='organization_id') then raise exception 'health_checks organization scope missing'; end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='error_events' and column_name='organization_id') then raise exception 'error_events organization scope missing'; end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='alert_rules' and column_name='category_id') then raise exception 'alert_rules category scope missing'; end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='recovery_events' and column_name='category_id') then raise exception 'recovery_events category scope missing'; end if;
  if not exists (select 1 from pg_indexes where schemaname='public' and indexname='observability_scope_time_idx') then raise exception 'observability scope index missing'; end if;
end $$;

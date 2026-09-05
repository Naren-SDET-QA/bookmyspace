-- Local contract checks; no data mutations.
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'integrations' and column_name = 'organization_id';
select indexname from pg_indexes where schemaname = 'public' and indexname = 'integrations_organization_idx';

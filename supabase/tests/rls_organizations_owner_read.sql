-- Read-only policy regression test. Run after migrations are applied.
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'organizations'
      and policyname = 'organizations_owner_read'
  ) then
    raise exception 'broad organizations_owner_read policy still exists';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'organizations'
      and policyname = 'organizations_select_owner_or_admin'
      and qual like '%owner_user_id%'
  ) then
    raise exception 'organizations must keep a row-scoped owner/admin select policy';
  end if;
end $$;

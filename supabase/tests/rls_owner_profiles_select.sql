-- Read-only policy regression test. Run after migrations are applied.
do $$
declare
  v_qual text;
begin
  select qual into v_qual
  from pg_policies
  where schemaname = 'public'
    and tablename = 'owner_profiles'
    and policyname = 'dev_owner_profiles_own'
    and cmd = 'ALL';

  if v_qual is null or v_qual not like '%user_id = auth.uid()%' then
    raise exception 'owner_profiles must be restricted to auth.uid(); policy qual=%', v_qual;
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'owner_profiles'
      and policyname in ('dev_owner_profiles_read', 'owner_profiles_owner_read', 'owner_profiles_own')
  ) then
    raise exception 'broad owner_profiles read policy still exists';
  end if;
end $$;

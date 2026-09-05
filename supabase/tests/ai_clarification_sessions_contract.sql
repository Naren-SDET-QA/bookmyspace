do $$
begin
  if to_regclass('public.ai_clarification_sessions') is null then
    raise exception 'ai_clarification_sessions table missing';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ai_clarification_sessions'
      and policyname = 'ai_clarification_owner_read'
  ) then raise exception 'owner read policy missing'; end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'ai_clarification_sessions'
      and grantee = 'anon' and privilege_type in ('SELECT','INSERT','UPDATE')
  ) then raise exception 'anonymous access must remain revoked'; end if;
end $$;

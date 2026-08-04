-- Allow RLS policies to resolve the current owner without exposing owner_profiles.
create or replace function public.get_owner_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.user_id
  from public.owner_profiles p
  where p.user_id = (select auth.uid())
$$;

revoke all on function public.get_owner_user_id() from public;
grant execute on function public.get_owner_user_id() to anon, authenticated;

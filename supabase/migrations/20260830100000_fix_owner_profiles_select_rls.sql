-- Restrict owner profile reads to the authenticated owner row.
-- The legacy policy only checked whether the caller owned any profile,
-- which exposed every owner_profiles row to any owner.
drop policy if exists dev_owner_profiles_read on public.owner_profiles;
drop policy if exists owner_profiles_owner_read on public.owner_profiles;

drop policy if exists owner_profiles_own on public.owner_profiles;
drop policy if exists dev_owner_profiles_own on public.owner_profiles;
create policy dev_owner_profiles_own on public.owner_profiles
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

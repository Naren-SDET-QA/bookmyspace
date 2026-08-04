-- The original local-only registration helper wrote directly to auth.users.
-- Owner onboarding now uses Supabase Auth followed by save_owner_profile().
revoke all on function public.register_owner(text, text, text) from public, anon, authenticated;

-- Policies call this helper internally; clients do not need direct access.
revoke all on function public.get_owner_user_id() from public, anon;
grant execute on function public.get_owner_user_id() to authenticated;

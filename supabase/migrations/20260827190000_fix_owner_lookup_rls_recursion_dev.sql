-- ============================================================
-- BookMySpace — DEV-only fix: get_owner_user_id() RLS self-recursion.
--
-- Found while verifying RLS as part of the owner-approval fix pass
-- (booking_orders_owner_read, which several new policies from
-- 20260827122210 depend on, joins through organizations).
--
-- public.get_owner_user_id() (0014_owner_registration.sql) queries
-- public.owner_profiles. public.owner_profiles has RLS policy
-- "owner_profiles_own" (0014) whose USING clause calls
-- get_owner_user_id(). Any non-superuser role (i.e. the real
-- `authenticated` role Supabase's API always uses — not a superuser,
-- which is the only role this recursion doesn't hit) evaluating that
-- policy re-enters get_owner_user_id(), which queries owner_profiles
-- again, re-triggering the same policy — infinite recursion,
-- "stack depth limit exceeded". This isn't specific to the new
-- booking-approval tables: it fires on ANY RLS-evaluated read of
-- public.organizations or public.owner_profiles as `authenticated`
-- (both "organizations_owner_write" and "organizations_owner_read",
-- 0014, also call get_owner_user_id()), so it is a pre-existing,
-- broad defect, not something introduced by the booking-approval
-- work — it was simply never exercised as a non-superuser role until
-- this verification pass.
--
-- Fix: mark get_owner_user_id() SECURITY DEFINER, the same pattern
-- already used throughout this codebase for privileged lookups
-- (owner_decide_booking, mark_ticket_resolved, delete_owner_account,
-- etc.). Its internal query then runs as the function's owning role
-- (the migration-applying role, which has BYPASSRLS in Supabase),
-- so it no longer re-triggers owner_profiles' RLS policy. No other
-- file changes — every existing caller of get_owner_user_id()
-- benefits automatically.
-- ============================================================

create or replace function public.get_owner_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.user_id
  from public.owner_profiles p
  where p.user_id = (select auth.uid())
$$;

revoke all on function public.get_owner_user_id() from public, anon;
grant execute on function public.get_owner_user_id() to authenticated, service_role;

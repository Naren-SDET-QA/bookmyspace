-- ============================================================
-- BookMySpace — DEV-only fix: has_role() lacks SECURITY DEFINER,
-- and two admin-read policies bypass it with an ad-hoc inline query.
--
-- Found while re-verifying RLS (Phase 16.7A, TEST 11) after the
-- previous booking_orders/booking_approval_events GRANT fix: the
-- query now reaches RLS evaluation, but fails with "permission
-- denied for table user_roles" for the `authenticated` role.
--
-- Root cause has two parts:
--
-- 1. public.has_role(uid, role) (0001_users_roles_organizations.sql)
--    is the codebase's own established, everywhere-used pattern for
--    role checks inside RLS policies — it's called from 23+ migration
--    files, including 0005_rls_policies.sql's own user_roles_read_own_or_admin
--    and user_roles_admin_write policies. But it was defined as plain
--    `language sql stable` — never `security definer` — so its internal
--    `select ... from public.user_roles` runs as the calling role. There
--    is no `grant select on public.user_roles to authenticated` anywhere
--    in the migration chain, so this has been broken for the real
--    `authenticated` role since it was written; it simply never got
--    exercised as a non-superuser role until this verification pass —
--    the same class of pre-existing, latent gap as the
--    get_owner_user_id() recursion fixed in
--    20260827190000_fix_owner_lookup_rls_recursion_dev.sql.
--
-- 2. booking_orders_admin_read and booking_approval_admin_read
--    (20260827122210_booking_owner_approval_token_flow.sql) don't even
--    use has_role() — they inline their own
--    `exists (select 1 from public.user_roles r where ...)` — the one
--    place in the whole codebase that deviates from the established
--    pattern instead of calling it.
--
-- Fix:
--  (a) mark has_role() SECURITY DEFINER SET search_path = public, the
--      same pattern already used throughout this codebase for
--      privileged lookups (get_owner_user_id, owner_decide_booking,
--      mark_ticket_resolved, delete_owner_account). Its internal query
--      then runs as the function's owning role (BYPASSRLS in Supabase),
--      so it needs no table grant and doesn't re-trigger user_roles'
--      own RLS policy (no recursion risk: BYPASSRLS skips policy
--      evaluation entirely). has_role() only ever returns a boolean —
--      it does not expose user_roles rows to the caller — so this does
--      not widen what any caller can see; every existing caller of
--      has_role() across the codebase is fixed for free, with no other
--      file changes.
--  (b) replace booking_orders_admin_read and booking_approval_admin_read
--      with the equivalent has_role() call, bringing them into line
--      with the established pattern instead of leaving a second,
--      inline path that would need its own separate grant. Same roles
--      checked (administrator, super_administrator), same
--      revoked_at is null requirement (baked into has_role() itself) —
--      semantics are unchanged, only the mechanism.
--
-- No booking logic, no other RLS policy, and no other authorization
-- check is touched. No table grant on user_roles is added — read
-- access to user_roles is still governed exclusively by
-- user_roles_read_own_or_admin, unchanged.
-- ============================================================

create or replace function public.has_role(uid uuid, r public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = uid and role = r and revoked_at is null
  );
$$;

revoke all on function public.has_role(uuid, public.user_role) from public, anon;
grant execute on function public.has_role(uuid, public.user_role) to authenticated, service_role;

drop policy if exists booking_orders_admin_read on public.booking_orders;
create policy booking_orders_admin_read on public.booking_orders for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

drop policy if exists booking_approval_admin_read on public.booking_approval_events;
create policy booking_approval_admin_read on public.booking_approval_events for select to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

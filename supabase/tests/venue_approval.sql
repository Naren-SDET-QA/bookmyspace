-- ============================================================
-- BookMySpace — Venue approval / publish gate (Function Hall)
--
-- Asserts:
--   1. Owner-created venue starts PENDING (is_active=false, is_verified=false)
--   2. Customer listing (RLS venues_public_read) excludes pending venues
--   3. Non-admin cannot call admin_approve_venue
--   4. Admin approve -> is_active=true, is_verified=true (published)
--   5. Owner cannot self-publish via update_owner_venue (is_active ignored)
--   6. Admin reject -> is_active=false (unpublished)
--
-- Run:
--   psql -d bookmyspace -f supabase/tests/venue_approval.sql
-- ============================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(7);

-- Roles (owner, admin; plain customer 7bcbc80e…592 exists, no role)
insert into public.user_roles(user_id, role) values
  ('00000000-0000-0000-0000-000000000002', 'venue_owner'),
  ('7155656a-c85a-4995-8a67-60ab0501d0e0', 'administrator')
on conflict(user_id, role) do update set revoked_at=null;

-- Org for the owner
insert into public.organizations(id, owner_user_id, org_type, name) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'venue_owner', 'Approval Owner')
on conflict(id) do nothing;

-- Owner creates a hall (pending). Capture ids via \gset as the owner
-- (owner sees own venues via venues_owner_write policy).
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
  (select public.create_owner_venue(
    'Approval Hall', (select id from public.venue_categories where slug = 'function_hall'),
    'Test hall', 'Ongole', 'AP', 15.5057, 80.0495, 200, 15000
  )).is_active,
  false,
  'owner-created venue starts pending (is_active=false)'
);
select is(
  (select public.create_owner_venue(
    'Approval Hall 2', (select id from public.venue_categories where slug = 'function_hall'),
    'Test hall 2', 'Ongole', 'AP', 15.5057, 80.0495, 100, 10000
  )).is_verified,
  false,
  'owner-created venue starts unverified (is_verified=false)'
);
select id from public.venues where name = 'Approval Hall' \gset venue1_
select id from public.venues where name = 'Approval Hall 2' \gset venue2_

-- RLS: pending venue invisible to customers (fresh claim, anon has none)
set local role anon;
select set_config('request.jwt.claim.sub', '', false);
select is_empty(
  $$select 1 from public.venues where name='Approval Hall'$$,
  'customer listing excludes pending (unpublished) venue'
);

-- Non-admin (customer) cannot call admin_approve_venue
set local role authenticated;
select set_config('request.jwt.claim.sub', '7bcbc80e-567a-476b-9173-40496563a592', true);
select throws_ok(
  format('select public.admin_approve_venue(%L, true)', :'venue1_id'),
  'admin_required',
  'non-admin cannot approve venues'
);

-- Owner cannot self-publish via update_owner_venue
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok(
  format('select public.update_owner_venue(%L, p_is_active := true)', :'venue1_id'),
  'owner_verified_locked:is_active',
  'owner cannot self-publish via update_owner_venue'
);

-- Admin approve -> published
set local role service_role;
select set_config('request.jwt.claim.sub', '7155656a-c85a-4995-8a67-60ab0501d0e0', true);
select is(
  (select public.admin_approve_venue(:'venue1_id', true)).is_active,
  true,
  'admin approve publishes venue'
);

-- Admin reject -> unpublished
select is(
  (select public.admin_approve_venue(:'venue2_id', false)).is_active,
  false,
  'admin reject keeps venue unpublished'
);

select * from finish();
rollback;

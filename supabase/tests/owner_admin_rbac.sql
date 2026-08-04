begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(5);

insert into public.user_roles(user_id, role) values
  ('00000000-0000-0000-0000-000000000002', 'venue_owner'),
  ('ca077c53-1968-4a18-bfc6-f58a8d0b8300', 'venue_owner'),
  ('7155656a-c85a-4995-8a67-60ab0501d0e0', 'administrator')
on conflict(user_id, role) do update set revoked_at=null;

insert into public.organizations(id, owner_user_id, org_type, name) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'venue_owner', 'RBAC Owner One'),
  ('10000000-0000-0000-0000-000000000002', 'ca077c53-1968-4a18-bfc6-f58a8d0b8300', 'venue_owner', 'RBAC Owner Two')
on conflict(id) do nothing;

insert into public.venues(id, org_id, name, latitude, longitude, capacity, is_active) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'RBAC Venue One', 15.5, 80.0, 10, false),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'RBAC Venue Two', 15.5, 80.0, 10, false)
on conflict(id) do nothing;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select results_eq(
  $$update public.venues set capacity=11 where id='20000000-0000-0000-0000-000000000001' returning id$$,
  array['20000000-0000-0000-0000-000000000001'::uuid],
  'owner can update own organization venue'
);
select is_empty(
  $$update public.venues set capacity=12 where id='20000000-0000-0000-0000-000000000002' returning id$$,
  'owner cannot update another organization venue'
);

select set_config('request.jwt.claim.sub', '7bcbc80e-567a-476b-9173-40496563a592', true);
select is_empty(
  $$update public.venues set capacity=13 where id='20000000-0000-0000-0000-000000000001' returning id$$,
  'customer cannot update owner venue'
);

select set_config('request.jwt.claim.sub', '7155656a-c85a-4995-8a67-60ab0501d0e0', true);
select results_eq(
  $$with updated as (update public.venues set capacity=14 where id in ('20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002') returning id) select id from updated order by id$$,
  array[
    '20000000-0000-0000-0000-000000000001'::uuid,
    '20000000-0000-0000-0000-000000000002'::uuid
  ],
  'administrator without venue_owner role has platform-wide access'
);
select ok(
  not public.has_role('7155656a-c85a-4995-8a67-60ab0501d0e0', 'venue_owner'),
  'administrator access does not require venue_owner role'
);

select * from finish();
rollback;

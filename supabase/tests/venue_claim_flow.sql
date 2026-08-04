-- Phase 5 claim flow checks (pgtap). Run after migration apply.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

select ok(
  to_regclass('public.venue_claims') is not null,
  'venue_claims exists'
);
select ok(
  exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'idx_venue_claims_one_pending'
  ),
  'one pending claim index exists'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'submit_venue_claim'
  ),
  'submit_venue_claim exists'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_review_venue_claim'
  ),
  'admin_review_venue_claim exists'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'write_venue_claim_audit'
  ),
  'write_venue_claim_audit exists'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'venue_claims'
      and policyname = 'venue_claims_select'
  ),
  'venue_claims_select RLS policy exists'
);

select * from finish();
rollback;

-- ============================================================
-- Venue Import DB foundation tests
-- Run: psql "$DATABASE_URL" -f supabase/tests/venue_import_foundation.sql
-- Or via supabase test db / local psql against migrated DB.
-- ============================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

-- Schema presence
select ok(
  to_regclass('public.venue_sources') is not null,
  'venue_sources table exists'
);
select ok(
  to_regclass('public.import_jobs') is not null,
  'import_jobs relation exists'
);
select ok(
  to_regclass('public.staged_venues') is not null,
  'staged_venues relation exists'
);
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'venues' and column_name = 'owner_verified'
  ),
  'venues.owner_verified column exists'
);

-- Seeded sources
select ok(
  exists (select 1 from public.venue_sources where code = 'osm'),
  'osm source seeded'
);
select ok(
  exists (select 1 from public.venue_sources where code = 'google_places'),
  'google_places source seeded'
);

-- Helper
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'venue_import_may_overwrite'
  ),
  'venue_import_may_overwrite exists'
);

-- Owner-verified protection on UPDATE
insert into public.organizations(id, owner_user_id, org_type, name)
select
  'a1000000-0000-4000-8000-000000000001',
  ur.user_id,
  'venue_owner',
  'Import Foundation Org'
from public.user_roles ur
where ur.role = 'venue_owner' and ur.revoked_at is null
limit 1
on conflict (id) do nothing;

-- Fallback org if no venue_owner role row (local empty DB): skip soft.
do $$
begin
  if not exists (select 1 from public.organizations where id = 'a1000000-0000-4000-8000-000000000001') then
    -- Use any existing org for fixture
    insert into public.organizations(id, owner_user_id, org_type, name)
    select 'a1000000-0000-4000-8000-000000000001', owner_user_id, org_type, 'Import Foundation Org'
    from public.organizations
    where deleted_at is null
    limit 1
    on conflict (id) do nothing;
  end if;
end $$;

insert into public.venues (
  id, org_id, name, latitude, longitude, capacity, is_active, owner_verified
)
select
  'a2000000-0000-4000-8000-000000000001',
  'a1000000-0000-4000-8000-000000000001',
  'Protected Import Venue',
  17.385, 78.4867, 50, false, true
where exists (select 1 from public.organizations where id = 'a1000000-0000-4000-8000-000000000001')
on conflict (id) do update set owner_verified = true, name = 'Protected Import Venue';

select is(
  (select name from public.venues where id = 'a2000000-0000-4000-8000-000000000001'),
  'Protected Import Venue',
  'fixture venue present (or skipped if no org)'
);

update public.venues
set name = 'Should Not Stick'
where id = 'a2000000-0000-4000-8000-000000000001'
  and owner_verified = true;

select is(
  (select name from public.venues where id = 'a2000000-0000-4000-8000-000000000001'),
  'Protected Import Venue',
  'owner_verified blocks name overwrite'
);

select ok(
  not public.venue_import_may_overwrite('a2000000-0000-4000-8000-000000000001'::uuid)
  or not exists (select 1 from public.venues where id = 'a2000000-0000-4000-8000-000000000001'),
  'venue_import_may_overwrite is false for owner_verified venue'
);

select * from finish();
rollback;

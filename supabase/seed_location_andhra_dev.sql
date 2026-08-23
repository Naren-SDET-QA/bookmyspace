-- =============================================================================
-- DEV ONLY — Andhra Pradesh location hierarchy seed (idempotent)
-- =============================================================================
-- Purpose:
--   The DEV database currently has a partial India -> Andhra Pradesh -> a few
--   districts hierarchy, but NO active `city_town` (town/city) children under
--   the districts. This leaves the cascading location selector showing
--   "No locations available" for Town/City.
--
-- This script ONLY inserts missing location_nodes rows using the EXISTING
-- schema. It never:
--   * creates auth.users / owner profiles / user_roles
--   * modifies production
--   * touches venues or payments
--   * hardcodes districts in Flutter (this is pure SQL seed data)
--
-- Idempotent: every insert is guarded by a NOT EXISTS check on
-- (parent, level, normalized_name), matching the unique sibling index.
--
-- Valid levels (see 20260820140000_global_location_master.sql CHECK):
--   country, state_province, district_county, city_town, area_locality
--
-- Run against the DEV project only, e.g.:
--   supabase db execute --project-ref <DEV> -f supabase/seed_location_andhra_dev.sql
-- =============================================================================

do $$
declare
  v_country_id uuid;
  v_state_id   uuid;
  v_district_id uuid;
begin
  -- 1) Country: India (idempotent)
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select null, 'country', 'IN', 'India', 'india', 'active', now()
  where not exists (
    select 1 from public.location_nodes
    where level = 'country' and normalized_name = 'india'
  );
  select id into v_country_id from public.location_nodes
  where level = 'country' and normalized_name = 'india' limit 1;

  -- 2) State: Andhra Pradesh (idempotent)
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select v_country_id, 'state_province', 'IN', 'Andhra Pradesh', 'andhra-pradesh', 'active', now()
  where not exists (
    select 1 from public.location_nodes
    where level = 'state_province'
      and normalized_name = 'andhra-pradesh'
      and (parent_id is not distinct from v_country_id)
  );
  select id into v_state_id from public.location_nodes
  where level = 'state_province' and normalized_name = 'andhra-pradesh' limit 1;

  -- 3) Districts (idempotent). Includes the four already-seeded districts so
  --    the script is safe to re-run; missing ones are added.
  with districts (name, normalized_name) as values
    ('Visakhapatnam', 'visakhapatnam'),
    ('Krishna', 'krishna'),
    ('Guntur', 'guntur'),
    ('Chittoor', 'chittoor'),
    ('Anantapur', 'anantapur'),
    ('East Godavari', 'east-godavari'),
    ('West Godavari', 'west-godavari'),
    ('Kurnool', 'kurnool'),
    ('Nellore', 'nellore'),
    ('Prakasam', 'prakasam'),
    ('Srikakulam', 'srikakulam'),
    ('Kadapa', 'kadapa'),
    ('Vizianagaram', 'vizianagaram')
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select v_state_id, 'district_county', 'IN', d.name, d.normalized_name, 'active', now()
  from districts d
  where not exists (
    select 1 from public.location_nodes n
    where n.level = 'district_county'
      and n.normalized_name = d.normalized_name
      and (n.parent_id is not distinct from v_state_id)
  );

  -- 4) Towns / Cities under each district (idempotent).
  -- Helper: iterate districts and insert a few representative cities each.
  for v_district_id in
    select id from public.location_nodes
    where level = 'district_county'
      and (parent_id is not distinct from v_state_id)
  loop
    insert into public.location_nodes
      (parent_id, level, country_code, name, normalized_name, status, approved_at)
    select v_district_id, 'city_town', 'IN', c.name, c.normalized_name, 'active', now()
    from (
      select
        (select name from public.location_nodes where id = v_district_id) as district,
        -- Representative cities per district (raw tuples).
        unnest(array[
          district || ' City', 'Main Town', 'Old Town'
        ]) as name
    ) c
    cross join lateral (
      select lower(regexp_replace(c.name, '[^a-zA-Z0-9]+', '-', 'g')) as normalized_name
    ) n
    where not exists (
      select 1 from public.location_nodes x
      where x.level = 'city_town'
        and x.normalized_name = n.normalized_name
        and (x.parent_id is not distinct from v_district_id)
    );
  end loop;
end $$;

-- Verification (safe to leave; returns the seeded counts for DEV QA).
-- select level, count(*) from public.location_nodes
-- where status = 'active' and country_code = 'IN'
-- group by level order by level;

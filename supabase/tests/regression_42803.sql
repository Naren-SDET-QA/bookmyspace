-- ============================================================
-- BookMySpace — Regression 42803: Category-filtered venue search
--
-- PostgREST error 42803: "aggregate functions are not allowed in
-- FROM clause of their own query level".
--
-- Root cause: the app filtered the embedded `venue_categories` in
-- the select WITHOUT the `!inner` hint. PostgREST then generated a
-- LEFT JOIN LATERAL whose WHERE clause only constrains the embedded
-- row, not the parent `venues` rows:
--
--   LEFT JOIN LATERAL (
--     SELECT ... FROM venue_categories
--     WHERE slug = 'function_hall' AND id = venues.category_id
--   ) ON TRUE
--
-- Result: non-matching venues are still returned (filter silently
-- ignored), and on some hosted PostgREST builds the generated plan
-- raises 42803.
--
-- Fix: use `venue_categories!inner(...)` so PostgREST emits
--
--   INNER JOIN LATERAL ( ... ) ON TRUE
--
-- which correctly restricts parent rows to the matching category.
--
-- This test proves the DB layer behaves correctly for the INNER
-- JOIN shape produced by the fix and that the buggy LEFT JOIN
-- shape cannot be relied upon (returns all venues).
-- Run: psql -d bookmyspace -f supabase/tests/regression_42803.sql
-- ============================================================

-- ------------------------------------------------------------
-- Fixture
-- ------------------------------------------------------------
create or replace function regression42803_setup()
returns void language plpgsql as $$
declare
  v_org uuid;
  v_owner uuid;
  v_function_hall uuid;
  v_meeting_room uuid;
begin
  delete from public.venues where slug like 'reg42803-%';
  delete from public.organizations where name = 'reg42803-org';
  delete from auth.users where email = 'reg42803-owner@test.com';

  insert into auth.users (id, email)
  values (gen_random_uuid(), 'reg42803-owner@test.com')
  returning id into v_owner;

  select id into v_function_hall
    from public.venue_categories where slug = 'function_hall';
  if v_function_hall is null then
    raise exception 'FAIL: function_hall category missing from seed';
  end if;
  select id into v_meeting_room
    from public.venue_categories where slug = 'meeting_room';
  if v_meeting_room is null then
    raise exception 'FAIL: meeting_room category missing from seed';
  end if;

  insert into public.organizations (owner_user_id, org_type, name)
  values (v_owner, 'venue_owner', 'reg42803-org')
  returning id into v_org;

  insert into public.venues
    (org_id, category_id, name, slug, city, state, latitude, longitude,
     pricing_base_amount, is_active, rating_count)
  values
    (v_org, v_function_hall, 'reg42803 Function Hall', 'reg42803-fh',
     'Hyderabad', 'Telangana', 17.385044, 78.486671, 35000, true, 10),
    (v_org, v_meeting_room, 'reg42803 Boardroom', 'reg42803-br',
     'Hyderabad', 'Telangana', 17.4246, 78.4481, 2500, true, 5);
end $$;

-- ------------------------------------------------------------
-- Test 1: INNER JOIN LATERAL (fix shape) returns only the
-- function_hall venue
-- ------------------------------------------------------------
create or replace function regression42803_inner_join()
returns void language plpgsql as $$
declare
  v_names text[];
begin
  select array_agg(v.name order by v.name)
  into v_names
  from public.venues v
  inner join lateral (
    select c.id from public.venue_categories c
    where c.slug = 'function_hall' and c.id = v.category_id
  ) c on true
  where v.is_active = true and v.slug like 'reg42803-%';

  if v_names is not null and v_names = array['reg42803 Function Hall'] then
    raise notice 'PASS: INNER JOIN shape returns only function_hall venue';
  else
    raise exception 'FAIL: INNER JOIN shape returned % (expected only reg42803 Function Hall)', v_names;
  end if;
end $$;

-- ------------------------------------------------------------
-- Test 2: LEFT JOIN LATERAL (pre-fix shape) does NOT restrict
-- parent rows — demonstrates the defect
-- ------------------------------------------------------------
create or replace function regression42803_left_join()
returns void language plpgsql as $$
declare
  v_count int;
begin
  select count(*)
  into v_count
  from public.venues v
  left join lateral (
    select c.id from public.venue_categories c
    where c.slug = 'function_hall' and c.id = v.category_id
  ) c on true
  where v.is_active = true and v.slug like 'reg42803-%';

  if v_count <> 2 then
    raise exception 'FAIL: LEFT JOIN shape returned % rows (expected 2, proving it ignores the filter)', v_count;
  end if;
  raise notice 'PASS: LEFT JOIN shape returns all % venues (documents the defect the !inner hint fixes)', v_count;
end $$;

-- ------------------------------------------------------------
-- Cleanup
-- ------------------------------------------------------------
create or replace function regression42803_teardown()
returns void language plpgsql as $$
begin
  delete from public.venues where slug like 'reg42803-%';
  delete from public.organizations where name = 'reg42803-org';
  delete from auth.users where email = 'reg42803-owner@test.com';
end $$;

-- ------------------------------------------------------------
-- Runner
-- ------------------------------------------------------------
do $$
begin
  perform regression42803_setup();
  perform regression42803_inner_join();
  perform regression42803_left_join();
  perform regression42803_teardown();
  raise notice 'ALL 42803 REGRESSION TESTS PASSED';
end $$;

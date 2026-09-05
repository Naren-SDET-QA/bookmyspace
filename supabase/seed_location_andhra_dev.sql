-- =============================================================================
-- DEV ONLY — Andhra Pradesh location hierarchy seed (idempotent)
-- =============================================================================
-- Purpose:
--   Fresh/DEV databases contain only a partial India -> Andhra Pradesh
--   -> few districts hierarchy without any active `city_town` children,
--   so the cascading location selector shows "No locations available"
--   for Town/City.
--
-- Guarantees:
--   * Uses the EXISTING location_nodes schema (levels allowed by CHECK:
--     country | state_province | district_county | city_town | area_locality).
--   * Idempotent: every insert is guarded by NOT EXISTS on
--     (parent, level, normalized_name) — matches the unique sibling index.
--   * No DELETEs, no Auth changes, no venue/payment changes.
--   * Deterministic names; safe to run repeatedly.
--
-- Run against DEV only:
--   supabase db query --file supabase/seed_location_andhra_dev.sql
-- =============================================================================

do $$
declare
  v_country_id uuid;
  v_state_id   uuid;
begin
  -- 1) Country: India -------------------------------------------------------
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select null, 'country', 'IN', 'India', 'india', 'active', now()
  where not exists (
    select 1 from public.location_nodes
    where level = 'country' and normalized_name = 'india'
  );

  select id into v_country_id
  from public.location_nodes
  where level = 'country' and normalized_name = 'india'
  limit 1;

  -- 2) State: Andhra Pradesh -----------------------------------------------
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select v_country_id, 'state_province', 'IN', 'Andhra Pradesh', 'andhra-pradesh', 'active', now()
  where not exists (
    select 1 from public.location_nodes
    where level = 'state_province'
      and normalized_name = 'andhra-pradesh'
      and parent_id is not distinct from v_country_id
  );

  select id into v_state_id
  from public.location_nodes
  where level = 'state_province' and normalized_name = 'andhra-pradesh'
  limit 1;

  -- 3) Districts (includes the four pre-existing ones; missing ones added) --
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select v_state_id, 'district_county', 'IN', d.district, d.slug, 'active', now()
  from (values
    ('Visakhapatnam',  'visakhapatnam'),
    ('Krishna',        'krishna'),
    ('Guntur',         'guntur'),
    ('Chittoor',       'chittoor'),
    ('Anantapur',      'anantapur'),
    ('East Godavari',  'east-godavari'),
    ('West Godavari',  'west-godavari'),
    ('Kurnool',        'kurnool'),
    ('Nellore',        'nellore'),
    ('Prakasam',       'prakasam'),
    ('Srikakulam',     'srikakulam'),
    ('Kadapa',         'kadapa'),
    ('Vizianagaram',   'vizianagaram')
  ) as d(district, slug)
  where not exists (
    select 1 from public.location_nodes n
    where n.level = 'district_county'
      and n.normalized_name = d.slug
      and n.parent_id is not distinct from v_state_id
  );

  -- 4) Towns / Cities under each district ----------------------------------
  insert into public.location_nodes
    (parent_id, level, country_code, name, normalized_name, status, approved_at)
  select p.id, 'city_town', 'IN', t.town,
         lower(regexp_replace(t.town, '\s+', '-', 'g')),
         'active', now()
  from (values
    ('visakhapatnam', 'Visakhapatnam'), ('visakhapatnam', 'Anakapalle'), ('visakhapatnam', 'Bheemunipatnam'),
    ('krishna',       'Vijayawada'),    ('krishna',       'Machilipatnam'), ('krishna',      'Gudivada'),
    ('guntur',        'Guntur'),        ('guntur',        'Tenali'),        ('guntur',       'Bapatla'),
    ('chittoor',      'Tirupati'),      ('chittoor',      'Chittoor'),      ('chittoor',     'Madanapalle'),
    ('anantapur',     'Anantapur'),     ('anantapur',     'Hindupur'),      ('anantapur',    'Dharmavaram'),
    ('east-godavari', 'Rajahmundry'),   ('east-godavari', 'Kakinada'),      ('east-godavari','Amalapuram'),
    ('west-godavari', 'Eluru'),         ('west-godavari', 'Bhimavaram'),    ('west-godavari','Tadepalligudem'),
    ('kurnool',       'Kurnool'),       ('kurnool',       'Nandyal'),       ('kurnool',      'Adoni'),
    ('nellore',       'Nellore'),       ('nellore',       'Gudur'),         ('nellore',      'Kavali'),
    ('prakasam',      'Ongole'),        ('prakasam',      'Chirala'),       ('prakasam',     'Markapur'),
    ('srikakulam',    'Srikakulam'),    ('srikakulam',    'Amadalavalasa'), ('srikakulam',   'Palasa'),
    ('kadapa',        'Kadapa'),        ('kadapa',        'Proddatur'),     ('kadapa',       'Pulivendula'),
    ('vizianagaram',  'Vizianagaram'),  ('vizianagaram',  'Parvathipuram'), ('vizianagaram', 'Bobbili')
  ) as t(district_slug, town)
  join public.location_nodes p
    on p.level = 'district_county'
   and p.normalized_name = t.district_slug
   and p.parent_id is not distinct from v_state_id
  where not exists (
    select 1 from public.location_nodes x
    where x.level = 'city_town'
      and x.normalized_name = lower(regexp_replace(t.town, '\s+', '-', 'g'))
      and x.parent_id is not distinct from p.id
  );
end $$;

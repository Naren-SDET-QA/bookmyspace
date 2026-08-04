-- Admin Content & Pricing Control tests
-- Run: psql "$DATABASE_URL" -f supabase/tests/admin_content_pricing.sql
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

select ok(
  to_regclass('public.homepage_sections') is not null,
  'homepage_sections exists'
);
select ok(
  to_regclass('public.home_category_tiles') is not null,
  'home_category_tiles exists'
);
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'venues' and column_name = 'is_featured'
  ),
  'venues.is_featured exists'
);
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'venues' and column_name = 'phone'
  ),
  'venues.phone exists'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_update_venue_content'
  ),
  'admin_update_venue_content exists'
);
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_homepage_content_config'
  ),
  'get_homepage_content_config exists'
);

select ok(
  exists (select 1 from public.homepage_sections where section_key = 'popular'),
  'popular section seeded'
);
select ok(
  exists (select 1 from public.home_category_tiles where tile_key = 'function_hall'),
  'function_hall tile seeded'
);
select ok(
  exists (select 1 from public.platform_settings where key = 'default_commission_rate'),
  'default_commission_rate seeded'
);

-- Owner-verified lock helper
select ok(
  exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_content_field_locked'
  ),
  'admin_content_field_locked exists'
);

-- Public config JSON shape
select ok(
  (public.get_homepage_content_config() ? 'sections')
  and (public.get_homepage_content_config() ? 'category_tiles'),
  'homepage config returns sections and tiles'
);

select ok(
  jsonb_array_length(public.get_homepage_content_config()->'category_tiles') >= 1,
  'homepage config has category tiles'
);

select * from finish();
rollback;

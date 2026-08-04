-- Phase 7: generalize venue import — all categories/states, district on jobs,
-- enable/disable category mappings. Places enrichment stays optional (app/edge).

-- ------------------------------------------------------------
-- New venue categories (halls already exist)
-- ------------------------------------------------------------
insert into public.venue_categories (slug, name) values
  ('hotel', 'Hotel'),
  ('resort', 'Resort'),
  ('institute', 'Institute'),
  ('classroom', 'Classroom'),
  ('event_space', 'Event Space')
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- Category mappings (OSM tags + optional Google type); enable/disable via is_active
-- ------------------------------------------------------------
insert into public.venue_import_category_mappings
  (category_slug, osm_tags, google_place_type, display_name, is_active)
values
  ('function_hall',
   '["amenity=events_venue","amenity=community_centre","name~=Function Hall|Kalyan|Marriage|Convention|Banquet|Mandapam"]'::jsonb,
   'event_venue', 'Function Hall', true),
  ('marriage_hall',
   '["amenity=events_venue","name~=Marriage|Kalyan|Wedding|Mandapam"]'::jsonb,
   'event_venue', 'Marriage Hall', true),
  ('convention_center',
   '["amenity=events_venue","building=convention_centre","name~=Convention|Banquet"]'::jsonb,
   'convention_center', 'Convention Center', true),
  ('party_hall',
   '["amenity=events_venue","name~=Party Hall|Banquet"]'::jsonb,
   'event_venue', 'Party Hall', true),
  ('meeting_room',
   '["amenity=conference_centre","office=coworking"]'::jsonb,
   'conference_room', 'Meeting Room', true),
  ('community_hall',
   '["amenity=community_centre"]'::jsonb,
   'community_center', 'Community Hall', true),
  ('sports_ground',
   '["leisure=sports_centre","leisure=pitch","leisure=stadium"]'::jsonb,
   'stadium', 'Sports Ground', true),
  ('coworking_space',
   '["amenity=coworking_space","office=coworking"]'::jsonb,
   'coworking_space', 'Coworking Space', true),
  ('auditorium',
   '["amenity=theatre","amenity=arts_centre"]'::jsonb,
   'performing_arts_theater', 'Auditorium', true),
  ('hotel',
   '["tourism=hotel"]'::jsonb,
   'lodging', 'Hotel', true),
  ('resort',
   '["tourism=resort","leisure=resort"]'::jsonb,
   'resort_hotel', 'Resort', true),
  ('institute',
   '["amenity=college","amenity=university","amenity=school","name~=Institute|Academy|College"]'::jsonb,
   'school', 'Institute', true),
  ('classroom',
   '["amenity=school","amenity=college","building=school"]'::jsonb,
   'school', 'Classroom', true),
  ('event_space',
   '["amenity=events_venue","amenity=community_centre"]'::jsonb,
   'event_venue', 'Event Space', true)
on conflict (category_slug) do update set
  osm_tags = excluded.osm_tags,
  google_place_type = excluded.google_place_type,
  display_name = excluded.display_name,
  is_active = coalesce(public.venue_import_category_mappings.is_active, excluded.is_active);

-- ------------------------------------------------------------
-- District on import jobs
-- ------------------------------------------------------------
alter table public.venue_import_jobs
  add column if not exists district text;

-- ------------------------------------------------------------
-- Create job with optional district (replace 4-arg overload)
-- ------------------------------------------------------------
drop function if exists public.admin_create_venue_import_job(text, text, text, text);

create or replace function public.admin_create_venue_import_job(
  p_country text,
  p_state text,
  p_category_slug text,
  p_source text default 'osm',
  p_district text default null
)
returns public.venue_import_jobs
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_job public.venue_import_jobs;
  v_active boolean;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  select m.is_active into v_active
  from public.venue_import_category_mappings m
  where m.category_slug = trim(p_category_slug);

  if v_active is null then
    raise exception 'category_mapping_not_found';
  end if;
  if not v_active then
    raise exception 'category_disabled';
  end if;

  insert into public.venue_import_jobs (
    country, state, district, category_slug, source, created_by
  )
  values (
    trim(p_country),
    trim(p_state),
    nullif(trim(coalesce(p_district, '')), ''),
    trim(p_category_slug),
    coalesce(nullif(trim(p_source), ''), 'osm'),
    auth.uid()
  )
  returning * into v_job;

  return v_job;
end;
$$;

revoke all on function public.admin_create_venue_import_job(text, text, text, text, text)
  from public, anon;
grant execute on function public.admin_create_venue_import_job(text, text, text, text, text)
  to authenticated;

-- ------------------------------------------------------------
-- Admin enable / disable category mapping
-- ------------------------------------------------------------
create or replace function public.admin_set_venue_import_category_active(
  p_category_slug text,
  p_is_active boolean
)
returns public.venue_import_category_mappings
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.venue_import_category_mappings;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  update public.venue_import_category_mappings
  set is_active = coalesce(p_is_active, false)
  where category_slug = trim(p_category_slug)
  returning * into v_row;

  if v_row is null then
    raise exception 'category_mapping_not_found';
  end if;
  return v_row;
end;
$$;

revoke all on function public.admin_set_venue_import_category_active(text, boolean)
  from public, anon;
grant execute on function public.admin_set_venue_import_category_active(text, boolean)
  to authenticated;

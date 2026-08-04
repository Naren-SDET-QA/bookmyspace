-- Phase 6: Google Places enrichment for OSM-staged venues (provenance preserved).

alter table public.venue_import_staging
  add column if not exists google_place_id text,
  add column if not exists enrichment_provenance jsonb not null default '{}'::jsonb;

create index if not exists idx_venue_import_staging_google_place
  on public.venue_import_staging(google_place_id)
  where google_place_id is not null;

-- Merge image_refs by url (dedupe).
create or replace function public.merge_venue_image_refs(
  p_existing jsonb,
  p_incoming jsonb
)
returns jsonb
language sql
immutable
as $$
  select coalesce(
    jsonb_agg(distinct elem),
    '[]'::jsonb
  )
  from (
    select elem
    from jsonb_array_elements(coalesce(p_existing, '[]'::jsonb)) elem
    union
    select elem
    from jsonb_array_elements(coalesce(p_incoming, '[]'::jsonb)) elem
  ) s;
$$;

-- Service-role enrichment: fills missing fields only; keeps OSM source/source_place_id.
create or replace function public.service_enrich_staging_venue(
  p_staging_id uuid,
  p_enrichment jsonb
)
returns public.venue_import_staging
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.venue_import_staging;
  v_google_id text := nullif(trim(p_enrichment->>'google_place_id'), '');
  v_dup uuid;
  v_phone text;
  v_website text;
begin
  select * into v_row from public.venue_import_staging where id = p_staging_id;
  if v_row is null then raise exception 'staging_not_found'; end if;

  if v_row.status in ('published', 'duplicate') then
    raise exception 'cannot_enrich_status';
  end if;

  if v_google_id is not null then
    select id into v_dup
    from public.venue_import_staging
    where google_place_id = v_google_id
      and id <> p_staging_id
    limit 1;
    if v_dup is not null then
      raise exception 'google_place_id_already_staged';
    end if;
  end if;

  v_phone := public.normalize_venue_phone(p_enrichment->>'phone');
  v_website := nullif(trim(p_enrichment->>'website'), '');

  update public.venue_import_staging
  set
    google_place_id = coalesce(v_google_id, google_place_id),
    phone = case
      when coalesce(phone, '') = '' and v_phone is not null then v_phone
      else phone end,
    website = case
      when coalesce(website, '') = '' and v_website is not null then v_website
      else website end,
    operating_hours = case
      when jsonb_array_length(coalesce(operating_hours, '[]'::jsonb)) = 0
           and jsonb_array_length(coalesce(p_enrichment->'operating_hours', '[]'::jsonb)) > 0
      then p_enrichment->'operating_hours'
      else operating_hours end,
    ratings = case
      when coalesce(ratings, '{}'::jsonb) = '{}'::jsonb
           and coalesce(p_enrichment->'ratings', '{}'::jsonb) <> '{}'::jsonb
      then p_enrichment->'ratings'
      else ratings end,
    image_refs = public.merge_venue_image_refs(
      image_refs,
      coalesce(p_enrichment->'image_refs', '[]'::jsonb)
    ),
    enrichment_provenance = enrichment_provenance
      || coalesce(p_enrichment->'enrichment_provenance', '{}'::jsonb),
    raw_payload = coalesce(raw_payload, '{}'::jsonb)
      || jsonb_build_object('last_enrichment', p_enrichment),
    status = 'pending_review'::public.venue_import_staging_status,
    updated_at = now()
  where id = p_staging_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.admin_enrich_staging_venue(
  p_staging_id uuid,
  p_enrichment jsonb
)
returns public.venue_import_staging
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin_user() then raise exception 'admin_required'; end if;
  return public.service_enrich_staging_venue(p_staging_id, p_enrichment);
end;
$$;

-- Refresh staged_venues view when backed by venue_import_staging.
-- DROP + CREATE required: CREATE OR REPLACE cannot rename/reorder view columns.
do $$
begin
  if to_regclass('public.venue_import_staging') is not null then
    execute 'drop view if exists public.staged_venues';
    execute $v$
      create view public.staged_venues as
      select
        s.id,
        s.job_id,
        s.status::text as status,
        s.name,
        s.category_slug as category,
        s.address_line1,
        s.address_line2,
        s.city,
        s.district,
        s.state,
        s.postal_code,
        s.country,
        s.phone,
        s.website,
        s.latitude,
        s.longitude,
        s.source,
        s.source_place_id,
        s.operating_hours,
        s.amenities,
        s.ratings,
        s.image_refs,
        s.fetched_at,
        s.published_venue_id,
        s.created_at,
        s.updated_at,
        s.google_place_id,
        s.enrichment_provenance
      from public.venue_import_staging s
    $v$;
    execute 'grant select on public.staged_venues to authenticated';
  end if;
end $$;

revoke all on function public.merge_venue_image_refs(jsonb, jsonb) from public, anon;
grant execute on function public.merge_venue_image_refs(jsonb, jsonb) to authenticated, service_role;

revoke all on function public.service_enrich_staging_venue(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.service_enrich_staging_venue(uuid, jsonb) to service_role;

revoke all on function public.admin_enrich_staging_venue(uuid, jsonb) from public, anon;
grant execute on function public.admin_enrich_staging_venue(uuid, jsonb) to authenticated;

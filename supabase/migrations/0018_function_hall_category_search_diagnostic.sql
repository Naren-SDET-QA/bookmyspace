-- ============================================================
-- BookMySpace — Migration 0018: Diagnostic & Fixed Function Hall Category Search RPC
--
-- Addresses Postgres 42803 (grouping / datatype mismatch error) during
-- venue category filtering by providing explicit UUID casting and structured
-- JSONB aggregate views without grouping ambiguities.
-- ============================================================

-- Function to safely search venues by category with explicit type casting and query logging
create or replace function public.search_venues_by_category(
  p_category_slug text default null,
  p_category_id uuid default null,
  p_search_query text default null,
  p_city text default null,
  p_min_price numeric default null,
  p_max_price numeric default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  name text,
  slug text,
  description text,
  city text,
  state text,
  latitude double precision,
  longitude double precision,
  capacity integer,
  pricing_base_amount numeric,
  tax_rate numeric,
  avg_rating numeric,
  rating_count integer,
  is_verified boolean,
  category_id uuid,
  venue_category jsonb,
  venue_images jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target_category_id uuid := p_category_id;
  v_sql text;
begin
  -- Resolve category ID from slug if slug provided and ID not given
  if v_target_category_id is null and p_category_slug is not null then
    select c.id into v_target_category_id
    from public.venue_categories c
    where c.slug = p_category_slug;
  end if;

  -- Diagnostic log statement
  raise notice 'Executing category search [slug=%, category_id=%::uuid, query=%, city=%]',
    p_category_slug, v_target_category_id, p_search_query, p_city;

  return query
  select 
    v.id,
    v.name,
    v.slug,
    v.description,
    v.city,
    v.state,
    v.latitude,
    v.longitude,
    v.capacity,
    v.pricing_base_amount,
    v.tax_rate,
    v.avg_rating,
    v.rating_count,
    v.is_verified,
    v.category_id,
    jsonb_build_object(
      'id', c.id,
      'slug', c.slug,
      'name', c.name,
      'icon', c.icon
    ) as venue_category,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', img.id,
            'url', img.url,
            'thumbnail_url', img.thumbnail_url,
            'alt_text', img.alt_text,
            'is_cover', img.is_cover,
            'sort_order', img.sort_order
          )
        )
        from public.venue_images img
        where img.venue_id = v.id
      ),
      '[]'::jsonb
    ) as venue_images
  from public.venues v
  inner join public.venue_categories c on c.id = v.category_id
  where v.is_active = true
    and (v_target_category_id is null or v.category_id = v_target_category_id::uuid)
    and (p_city is null or v.city ilike '%' || p_city || '%')
    and (p_min_price is null or v.pricing_base_amount >= p_min_price)
    and (p_max_price is null or v.pricing_base_amount <= p_max_price)
    and (p_search_query is null or v.search_document @@ to_tsquery(p_search_query))
  order by v.avg_rating desc, v.rating_count desc
  limit p_limit;
end;
$$;

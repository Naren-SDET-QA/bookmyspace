-- ============================================================
-- BookMySpace — Migration 0009: Nearby Venues RPC
--
-- A single RPC for distance-sorted venue lookup, used by the home
-- screen ("nearby") and any geospatial search. Security invoker +
-- RLS still applies to the underlying venues table.
-- ============================================================

create or replace function public.nearby_venues(
  p_lat double precision,
  p_lng double precision,
  radius_km double precision default 25,
  max_rows integer default 20
)
returns table (
  id uuid,
  org_id uuid,
  category_id uuid,
  name text,
  slug text,
  description text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country text,
  latitude double precision,
  longitude double precision,
  capacity integer,
  pricing_base_amount numeric(12,2),
  pricing_currency text,
  tax_rate numeric(5,2),
  parking_capacity integer,
  food_options text,
  rules text,
  cancellation_policy jsonb,
  is_verified boolean,
  is_active boolean,
  avg_rating numeric(3,2),
  rating_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  deleted_at timestamptz,
  search_document tsvector,
  distance_km double precision,
  venue_categories jsonb,
  venue_images jsonb
)
language sql
stable
security invoker
as $$
  select
    v.id, v.org_id, v.category_id, v.name, v.slug, v.description,
    v.address_line1, v.address_line2, v.city, v.state, v.postal_code,
    v.country, v.latitude, v.longitude, v.capacity,
    v.pricing_base_amount, v.pricing_currency, v.tax_rate,
    v.parking_capacity, v.food_options, v.rules, v.cancellation_policy,
    v.is_verified, v.is_active, v.avg_rating, v.rating_count,
    v.created_at, v.updated_at, v.deleted_at, v.search_document,
    (st_distance(v.geog, st_makepoint(p_lng, p_lat)::geography) / 1000.0)::double precision as distance_km,
    jsonb_build_object(
      'id', c.id, 'slug', c.slug, 'name', c.name, 'icon', c.icon
    ) as venue_categories,
    coalesce(
      (select jsonb_agg(jsonb_build_object(
          'id', img.id,
          'url', img.url,
          'thumbnail_url', img.thumbnail_url,
          'alt_text', img.alt_text,
          'is_cover', img.is_cover,
          'sort_order', img.sort_order
        ) order by img.is_cover desc, img.sort_order asc)
       from public.venue_images img where img.venue_id = v.id),
      '[]'::jsonb
    ) as venue_images
  from public.venues v
  left join public.venue_categories c on c.id = v.category_id
  where v.is_active
    and v.deleted_at is null
    and st_dwithin(
      v.geog,
      st_makepoint(p_lng, p_lat)::geography,
      radius_km * 1000
    )
  order by distance_km asc
  limit max_rows;
$$;

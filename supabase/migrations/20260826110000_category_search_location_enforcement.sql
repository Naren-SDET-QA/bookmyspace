-- Preserve search_venues' public contract while making category metadata
-- authoritative for public search and location-aware discovery.
create or replace function public.search_venues(
  p_query text default null, p_location_node_id uuid default null,
  p_lat double precision default null, p_lng double precision default null,
  p_radius_km double precision default 50, p_category_id uuid default null,
  p_min_price numeric default null, p_max_price numeric default null,
  p_min_rating numeric default null, p_min_capacity integer default null,
  p_amenity_ids uuid[] default null, p_sort text default 'recommended',
  p_page integer default 0, p_page_size integer default 20
)
returns table (
  id uuid, org_id uuid, category_id uuid, name text, slug text, description text,
  address_line1 text, address_line2 text, city text, state text, postal_code text,
  country text, location_node_id uuid, latitude double precision, longitude double precision,
  capacity integer, pricing_base_amount numeric, pricing_currency text, tax_rate numeric,
  parking_capacity integer, food_options text, rules text, cancellation_policy jsonb,
  is_verified boolean, is_active boolean, avg_rating numeric, rating_count integer,
  created_at timestamptz, updated_at timestamptz, deleted_at timestamptz,
  distance_km double precision, venue_categories jsonb, venue_images jsonb, venue_facilities jsonb
)
language sql stable security invoker set search_path = public
as $$
with recursive descendants as (
  select id from public.location_nodes where p_location_node_id is not null and id = p_location_node_id
  union all
  select n.id from public.location_nodes n join descendants d on n.parent_id = d.id
), candidates as (
  select v.*, c.id as c_id, c.slug as c_slug, c.name as c_name, c.icon as c_icon,
    case when p_lat is not null and p_lng is not null and v.geog is not null
      then (st_distance(v.geog, st_makepoint(p_lng, p_lat)::geography) / 1000.0)::double precision end as dist
  from public.venues v left join public.venue_categories c on c.id = v.category_id
  where v.is_active and v.deleted_at is null
    and case when jsonb_typeof(c.metadata->'active') = 'boolean' then (c.metadata->>'active')::boolean else false end
    and case when jsonb_typeof(c.metadata->'searchable') = 'boolean' then (c.metadata->>'searchable')::boolean else false end
    and (p_query is null or p_query = '' or v.search_document @@ plainto_tsquery('simple', p_query))
    and (p_category_id is null or v.category_id = p_category_id)
    and (p_location_node_id is null or (
      case when jsonb_typeof(c.metadata->'location_enabled') = 'boolean' then (c.metadata->>'location_enabled')::boolean else false end
      and v.location_node_id in (select id from descendants)
    ))
    and (p_min_price is null or v.pricing_base_amount >= p_min_price)
    and (p_max_price is null or v.pricing_base_amount <= p_max_price)
    and (p_min_rating is null or v.avg_rating >= p_min_rating)
    and (p_min_capacity is null or v.capacity >= p_min_capacity)
    and (p_lat is null or p_lng is null or v.geog is null or st_dwithin(v.geog, st_makepoint(p_lng, p_lat)::geography, p_radius_km * 1000))
    and (p_amenity_ids is null or not exists (select 1 from unnest(p_amenity_ids) x where not exists (select 1 from public.venue_amenities va where va.venue_id = v.id and va.amenity_id = x)))
), page as (
  select * from candidates order by
    case when p_sort = 'nearest' then dist end asc nulls last,
    case when p_sort = 'lowest_price' then pricing_base_amount end asc nulls last,
    case when p_sort = 'highest_price' then pricing_base_amount end desc nulls last,
    case when p_sort = 'highest_rating' then avg_rating end desc nulls last,
    rating_count desc, created_at desc
  offset greatest(0, p_page) * greatest(1, least(p_page_size, 100))
  limit greatest(1, least(p_page_size, 100))
)
select p.id, p.org_id, p.category_id, p.name, p.slug, p.description, p.address_line1, p.address_line2,
 p.city, p.state, p.postal_code, p.country, p.location_node_id, p.latitude, p.longitude, p.capacity,
 p.pricing_base_amount, p.pricing_currency, p.tax_rate, p.parking_capacity, p.food_options, p.rules,
 p.cancellation_policy, p.is_verified, p.is_active, p.avg_rating, p.rating_count, p.created_at, p.updated_at,
 p.deleted_at, p.dist, jsonb_build_object('id',p.c_id,'slug',p.c_slug,'name',p.c_name,'icon',p.c_icon),
 coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'url',i.url,'thumbnail_url',i.thumbnail_url,'alt_text',i.alt_text,'is_cover',i.is_cover,'sort_order',i.sort_order) order by i.is_cover desc,i.sort_order) from public.venue_images i where i.venue_id=p.id),'[]'::jsonb),
 coalesce((select jsonb_agg(jsonb_build_object('facility',a.name,'is_available',true) order by a.sort_order) from public.venue_amenities va join public.amenities a on a.id=va.amenity_id where va.venue_id=p.id and a.status='active'),'[]'::jsonb)
from page p;
$$;

revoke all on function public.search_venues(text,uuid,double precision,double precision,double precision,uuid,numeric,numeric,numeric,integer,uuid[],text,integer,integer) from public;
grant execute on function public.search_venues(text,uuid,double precision,double precision,double precision,uuid,numeric,numeric,numeric,integer,uuid[],text,integer,integer) to anon, authenticated;

-- Read-only verification for seed_all_categories_dev.sql.
-- Run only against the intended DEV database.

select
  vc.slug,
  vc.name,
  count(v.id) filter (where v.is_active and v.deleted_at is null) as active_venues,
  count(distinct v.location_node_id) as locations_used,
  count(distinct vi.id) as images,
  count(distinct vf.id) as facilities,
  count(distinct ts.id) as time_slots
from public.venue_categories vc
left join public.venues v on v.category_id = vc.id
left join public.venue_images vi on vi.venue_id = v.id
left join public.venue_facilities vf on vf.venue_id = v.id
left join public.time_slots ts on ts.venue_id = v.id
where v.slug like 'bms-dev-generic-%'
   or v.id is null
group by vc.id, vc.slug, vc.name
order by vc.slug;

select
  vc.slug,
  count(v.id) as deterministic_venue_count,
  count(distinct v.slug) as deterministic_slug_count
from public.venue_categories vc
left join public.venues v
  on v.category_id = vc.id
 and v.slug like 'bms-dev-generic-%'
group by vc.id, vc.slug
order by vc.slug;

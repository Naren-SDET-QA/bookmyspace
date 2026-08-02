-- ============================================================
-- BookMySpace — Migration 0010: Demo Content (images, hours, venues)
--
-- Development / local seed data. Idempotent. Extends 0007 so the
-- app has realistic gallery, facilities and hours to render.
-- ============================================================

-- Cover images use Unsplash URLs (no API key required for hotlinking).
do $$
declare
  v_sunrise uuid;
  v_boardroom uuid;
begin
  select id into v_sunrise from public.venues where slug = 'sunrise-function-hall';
  select id into v_boardroom from public.venues where slug = 'the-boardroom';

  -- Sunrise Function Hall gallery
  insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
  select v_sunrise, 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3',
    'Sunrise function hall main hall', true, 0
  where not exists (select 1 from public.venue_images where venue_id = v_sunrise);

  insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
  select v_sunrise, 'https://images.unsplash.com/photo-1511578314322-379afb476865',
    'Decorative entrance', false, 1
  where not exists (
    select 1 from public.venue_images
    where venue_id = v_sunrise and url = 'https://images.unsplash.com/photo-1511578314322-379afb476865'
  );

  insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
  select v_sunrise, 'https://images.unsplash.com/photo-1505236858219-8359eb29e329',
    'Banquet setup', false, 2
  where not exists (
    select 1 from public.venue_images
    where venue_id = v_sunrise and url = 'https://images.unsplash.com/photo-1505236858219-8359eb29e329'
  );

  -- The Boardroom gallery
  insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
  select v_boardroom, 'https://images.unsplash.com/photo-1497366216548-37526070297c',
    'Modern meeting room', true, 0
  where not exists (select 1 from public.venue_images where venue_id = v_boardroom);
end $$;

-- Operating hours for The Boardroom.
insert into public.venue_operating_hours (venue_id, day_of_week, opens_at, closes_at)
select v.id, d, '08:00', '20:00'
from public.venues v, generate_series(0, 6) as d
where v.slug = 'the-boardroom'
  and not exists (
    select 1 from public.venue_operating_hours oh
    where oh.venue_id = v.id and oh.day_of_week = d
  );

-- A third demo venue to give the home screen more content.
insert into public.venues (
  org_id, category_id, name, slug, description, city, state, latitude,
  longitude, capacity, pricing_base_amount, tax_rate, parking_capacity,
  food_options, is_verified, avg_rating, rating_count
)
select
  (select id from public.organizations where name = 'Demo Venues'),
  (select id from public.venue_categories where slug = 'coworking_space'),
  'The Work Nest',
  'the-work-nest',
  'Flexible coworking with high-speed internet, meeting pods and a café.',
  'Bengaluru', 'Karnataka', 12.9716, 77.5946, 80, 500, 18, 25,
  'In-house café and vending', true, 4.7, 214
where exists (select 1 from public.organizations where name = 'Demo Venues')
  and not exists (select 1 from public.venues where slug = 'the-work-nest');

insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
select v.id, 'https://images.unsplash.com/photo-1497366811353-6870744d04b2',
  'Open coworking area', true, 0
from public.venues v
where v.slug = 'the-work-nest'
  and not exists (select 1 from public.venue_images where venue_id = v.id);

insert into public.venue_operating_hours (venue_id, day_of_week, opens_at, closes_at)
select v.id, d, '09:00', '22:00'
from public.venues v, generate_series(0, 6) as d
where v.slug = 'the-work-nest'
  and not exists (
    select 1 from public.venue_operating_hours oh
    where oh.venue_id = v.id and oh.day_of_week = d
  );

insert into public.venue_facilities (venue_id, facility)
select v.id, f
from public.venues v, unnest(array[
  'High-speed WiFi', 'Meeting Pods', 'Café', 'Parking', '24/7 Access'
]) as f
where v.slug = 'the-work-nest'
  and not exists (
    select 1 from public.venue_facilities vf
    where vf.venue_id = v.id and vf.facility = f
  );

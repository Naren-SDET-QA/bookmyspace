-- ============================================================
-- BookMySpace — Migration 0002: Venues, Categories, Facilities
-- ============================================================

create type public.venue_category as enum (
  'function_hall',
  'marriage_hall',
  'convention_center',
  'party_hall',
  'meeting_room',
  'community_hall',
  'sports_ground',
  'coworking_space',
  'auditorium'
);

create table public.venue_categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  icon text
);

create table public.venues (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid references public.venue_categories(id),
  name text not null,
  slug text,
  description text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  postal_code text,
  country text not null default 'IN',
  latitude double precision not null,
  longitude double precision not null,
  geog geography(Point, 4326) generated always as (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  ) stored,
  capacity integer check (capacity > 0),
  pricing_base_amount numeric(12,2) not null default 0 check (pricing_base_amount >= 0),
  pricing_currency text not null default 'INR',
  tax_rate numeric(5,2) not null default 18.00 check (tax_rate >= 0 and tax_rate <= 100),
  parking_capacity integer,
  food_options text,
  rules text,
  cancellation_policy jsonb,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  avg_rating numeric(3,2) not null default 0 check (avg_rating >= 0 and avg_rating <= 5),
  rating_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  search_document tsvector generated always as (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(city, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  ) stored
);

create table public.venue_images (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  url text not null,
  thumbnail_url text,
  alt_text text,
  is_cover boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table public.venue_facilities (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  facility text not null,
  is_available boolean not null default true,
  unique (venue_id, facility)
);

create table public.venue_operating_hours (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  is_closed boolean not null default false,
  unique (venue_id, day_of_week)
);

-- ------------------------------------------------------------
-- INDEXES (geospatial, full-text, common query patterns)
-- ------------------------------------------------------------
create index idx_venues_geog on public.venues using gist (geog);
create index idx_venues_fts on public.venues using gin (search_document);
create index idx_venues_city on public.venues(city) where deleted_at is null and is_active;
create index idx_venues_category on public.venues(category_id);
create index idx_venues_org on public.venues(org_id);
create index idx_venues_active on public.venues(latitude, longitude) where deleted_at is null and is_active;
create index idx_venue_images_cover on public.venue_images(venue_id, is_cover);

create trigger trg_venues_updated_at before update on public.venues
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- SEED: venue categories
-- ------------------------------------------------------------
insert into public.venue_categories (slug, name) values
  ('function_hall', 'Function Hall'),
  ('marriage_hall', 'Marriage Hall'),
  ('convention_center', 'Convention Center'),
  ('party_hall', 'Party Hall'),
  ('meeting_room', 'Meeting Room'),
  ('community_hall', 'Community Hall'),
  ('sports_ground', 'Sports Ground'),
  ('coworking_space', 'Coworking Space'),
  ('auditorium', 'Auditorium')
on conflict (slug) do nothing;

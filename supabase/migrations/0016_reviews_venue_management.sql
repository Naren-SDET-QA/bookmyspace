-- ============================================================
-- BookMySpace — Migration 0016: Reviews & Venue Management
-- ============================================================

-- Reviews table: users can review venues they've booked.
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete set null,
  rating integer not null check (rating >= 1 and rating <= 5),
  title text,
  body text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, user_id)
);

-- Index for fast venue lookups.
create index idx_reviews_venue_id on public.reviews(venue_id);
create index idx_reviews_user_id on public.reviews(user_id);

-- RLS: anyone can read reviews; only the author can update/delete their own.
alter table public.reviews enable row level security;

create policy "Reviews are publicly readable"
  on public.reviews for select
  using (true);

create policy "Authenticated users can insert reviews"
  on public.reviews for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own reviews"
  on public.reviews for update
  using (auth.uid() = user_id);

create policy "Users can delete their own reviews"
  on public.reviews for delete
  using (auth.uid() = user_id);

-- Function to recalculate venue avg_rating and rating_count.
create or replace function public.update_venue_rating(p_venue_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.venues
  set
    avg_rating = coalesce(
      (select avg(r.rating)::numeric(3,2) from public.reviews r where r.venue_id = p_venue_id),
      0
    ),
    rating_count = (
      select count(*)::integer from public.reviews r where r.venue_id = p_venue_id
    ),
    updated_at = now()
  where id = p_venue_id;
end;
$$;

-- Trigger to auto-update venue rating after review insert/update/delete.
create or replace function public.reviews_rating_trigger()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    perform public.update_venue_rating(new.venue_id);
  end if;
  if tg_op = 'DELETE' then
    perform public.update_venue_rating(old.venue_id);
  end if;
  return null;
end;
$$;

create trigger reviews_rating_changes
  after insert or update or delete on public.reviews
  for each row
  execute function public.reviews_rating_trigger();

-- Owner venue management: allow owners to CRUD venues via their org.
-- RLS is handled by org ownership; this migration adds helper functions.

-- Function to get owner's organization venues.
create or replace function public.get_owner_venues()
returns setof public.venues
language sql
security definer
stable
as $$
  select v.*
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where o.owner_user_id = auth.uid()
    and v.deleted_at is null
  order by v.created_at desc;
$$;

-- Function to create a venue as an owner.
create or replace function public.create_owner_venue(
  p_name text,
  p_category_id uuid,
  p_description text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_capacity integer,
  p_pricing_base_amount numeric
)
returns public.venues
language plpgsql
security definer
as $$
declare
  v_org_id uuid;
  v_venue public.venues;
begin
  -- Get owner's org.
  select id into v_org_id
  from public.organizations
  where owner_user_id = auth.uid()
  limit 1;

  if v_org_id is null then
    raise exception 'owner_org_not_found';
  end if;

  insert into public.venues (
    org_id, category_id, name, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, slug
  ) values (
    v_org_id, p_category_id, p_name, p_description, p_city, p_state,
    p_latitude, p_longitude, p_capacity, p_pricing_base_amount,
    lower(replace(p_name, ' ', '-'))
  ) returning * into v_venue;

  return v_venue;
end;
$$;

-- Function to update a venue (owner only).
create or replace function public.update_owner_venue(
  p_venue_id uuid,
  p_name text default null,
  p_category_id uuid default null,
  p_description text default null,
  p_city text default null,
  p_state text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_capacity integer default null,
  p_pricing_base_amount numeric default null,
  p_is_active boolean default null
)
returns public.venues
language plpgsql
security definer
as $$
declare
  v_venue public.venues;
begin
  -- Verify ownership.
  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid();

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set
    name = coalesce(p_name, name),
    category_id = coalesce(p_category_id, category_id),
    description = coalesce(p_description, description),
    city = coalesce(p_city, city),
    state = coalesce(p_state, state),
    latitude = coalesce(p_latitude, latitude),
    longitude = coalesce(p_longitude, longitude),
    capacity = coalesce(p_capacity, capacity),
    pricing_base_amount = coalesce(p_pricing_base_amount, pricing_base_amount),
    is_active = coalesce(p_is_active, is_active),
    slug = case when p_name is not null then lower(replace(p_name, ' ', '-')) else slug end,
    updated_at = now()
  where id = p_venue_id
  returning * into v_venue;

  return v_venue;
end;
$$;

-- Function to soft-delete a venue (owner only).
create or replace function public.delete_owner_venue(p_venue_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_exists boolean;
begin
  select exists(
    select 1
    from public.venues v
    join public.organizations o on o.id = v.org_id
    where v.id = p_venue_id
      and o.owner_user_id = auth.uid()
  ) into v_exists;

  if not v_exists then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set deleted_at = now(), is_active = false
  where id = p_venue_id;
end;
$$;

-- Seed demo reviews for existing venues.
do $$
declare
  v_sunrise uuid;
  v_boardroom uuid;
  v_worknest uuid;
  v_user uuid;
begin
  select id into v_sunrise from public.venues where slug = 'sunrise-function-hall';
  select id into v_boardroom from public.venues where slug = 'the-boardroom';
  select id into v_worknest from public.venues where slug = 'the-work-nest';
  select id into v_user from auth.users where email = 'user@demo.com' limit 1;

  if v_user is not null then
    insert into public.reviews (venue_id, user_id, rating, title, body, is_verified)
    values
      (v_sunrise, v_user, 5, 'Excellent venue!', 'Great hall, well-maintained and spacious. Perfect for our event.', true),
      (v_boardroom, v_user, 4, 'Professional setup', 'Good meeting room with modern amenities. Slightly expensive.', true),
      (v_worknest, v_user, 4, 'Great coworking space', 'Fast internet and comfortable seating. The café is a nice touch.', true)
    on conflict (venue_id, user_id) do nothing;
  end if;
end $$;

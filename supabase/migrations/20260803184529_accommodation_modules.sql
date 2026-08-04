-- Independent accommodation catalogue for PG/co-living and short stays.
create table public.accommodation_properties (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  module text not null check (module in ('pg', 'stay')),
  property_type text not null,
  gender_policy text check (gender_policy in ('men', 'women', 'unisex')),
  name text not null,
  description text not null default '',
  address text not null default '',
  city text not null,
  latitude double precision,
  longitude double precision,
  cover_image text,
  amenities text[] not null default '{}',
  food_included boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint accommodation_gender_check check (
    (module = 'pg' and gender_policy is not null) or
    (module = 'stay' and gender_policy is null)
  )
);

create table public.accommodation_units (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.accommodation_properties(id) on delete cascade,
  name text not null,
  occupancy_type text not null,
  capacity integer not null default 1 check (capacity > 0),
  inventory integer not null default 1 check (inventory > 0),
  rent_monthly numeric(12,2) check (rent_monthly >= 0),
  price_nightly numeric(12,2) check (price_nightly >= 0),
  deposit numeric(12,2) not null default 0 check (deposit >= 0),
  available_from date not null default current_date,
  amenities text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint accommodation_unit_price_check check (
    (rent_monthly is not null and price_nightly is null) or
    (rent_monthly is null and price_nightly is not null)
  )
);

create table public.accommodation_visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.accommodation_properties(id) on delete cascade,
  visit_at timestamptz not null,
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table public.accommodation_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  property_id uuid not null references public.accommodation_properties(id) on delete restrict,
  unit_id uuid not null references public.accommodation_units(id) on delete restrict,
  module text not null check (module in ('pg','stay')),
  move_in_date date,
  check_in date,
  check_out date,
  guests integer not null default 1 check (guests > 0),
  amount numeric(12,2) not null default 0 check (amount >= 0),
  status text not null default 'reserved' check (status in ('reserved','confirmed','cancelled','completed')),
  created_at timestamptz not null default now(),
  constraint accommodation_reservation_dates_check check (
    (module = 'pg' and move_in_date is not null and check_in is null and check_out is null) or
    (module = 'stay' and move_in_date is null and check_in is not null and check_out > check_in)
  )
);

create index accommodation_properties_module_city_idx
  on public.accommodation_properties(module, city) where is_active;
create index accommodation_units_property_idx
  on public.accommodation_units(property_id) where is_active;
create index accommodation_reservations_inventory_idx
  on public.accommodation_reservations(unit_id, status, check_in, check_out);

alter table public.accommodation_properties enable row level security;
alter table public.accommodation_units enable row level security;
alter table public.accommodation_visits enable row level security;
alter table public.accommodation_reservations enable row level security;

create policy accommodation_properties_public_read
  on public.accommodation_properties for select
  to anon, authenticated using (is_active);
create policy accommodation_properties_owner_write
  on public.accommodation_properties for all to authenticated
  using (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ));

create policy accommodation_units_public_read
  on public.accommodation_units for select
  to anon, authenticated using (
    is_active and exists (
      select 1 from public.accommodation_properties p
      where p.id = property_id and p.is_active
    )
  );

create policy accommodation_visits_own
  on public.accommodation_visits for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy accommodation_reservations_own_read
  on public.accommodation_reservations for select to authenticated
  using ((select auth.uid()) = user_id);

grant select on public.accommodation_properties, public.accommodation_units to anon, authenticated;
grant select, insert, update on public.accommodation_visits to authenticated;
grant select on public.accommodation_reservations to authenticated;

create or replace function public.reserve_accommodation(
  p_property_id uuid,
  p_unit_id uuid,
  p_move_in date default null,
  p_check_in date default null,
  p_check_out date default null,
  p_guests integer default 1
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_module text;
  v_inventory integer;
  v_price numeric(12,2);
  v_reserved bigint;
  v_id uuid;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  if p_guests < 1 then raise exception 'invalid guest count'; end if;

  perform pg_advisory_xact_lock(hashtext(p_unit_id::text));
  select p.module, u.inventory,
    case when p.module = 'pg' then u.rent_monthly else u.price_nightly end
  into v_module, v_inventory, v_price
  from public.accommodation_properties p
  join public.accommodation_units u on u.property_id = p.id
  where p.id = p_property_id and u.id = p_unit_id
    and p.is_active and u.is_active
    and u.available_from <= coalesce(p_move_in, p_check_in);

  if not found then raise exception 'unit unavailable'; end if;

  if v_module = 'pg' then
    if p_move_in is null or p_move_in < current_date then
      raise exception 'invalid move-in date';
    end if;
    select count(*) into v_reserved
      from public.accommodation_reservations
      where unit_id = p_unit_id and status in ('reserved','confirmed');
  else
    if p_check_in is null or p_check_out is null or p_check_in < current_date or p_check_out <= p_check_in then
      raise exception 'invalid stay dates';
    end if;
    select count(*) into v_reserved
      from public.accommodation_reservations
      where unit_id = p_unit_id and status in ('reserved','confirmed')
        and check_in < p_check_out and check_out > p_check_in;
  end if;

  if v_reserved >= v_inventory then raise exception 'unit unavailable'; end if;

  insert into public.accommodation_reservations (
    user_id, property_id, unit_id, module, move_in_date,
    check_in, check_out, guests, amount
  ) values (
    v_user, p_property_id, p_unit_id, v_module, p_move_in,
    p_check_in, p_check_out, p_guests,
    case when v_module = 'pg' then v_price
      else v_price * (p_check_out - p_check_in) end
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.reserve_accommodation(uuid,uuid,date,date,date,integer) from public, anon;
grant execute on function public.reserve_accommodation(uuid,uuid,date,date,date,integer) to authenticated;

-- Local catalogue rows are inserted only when the existing demo owner exists.
insert into public.accommodation_properties
  (org_id,module,property_type,gender_policy,name,description,address,city,amenities,food_included)
select id,'pg','co_living','unisex','UrbanNest Co-Living','Managed co-living with furnished rooms and daily essentials.','Madhapur','Hyderabad',array['Wi-Fi','Laundry','Power backup','Housekeeping'],true
from public.organizations where name='Demo Venues'
on conflict do nothing;

insert into public.accommodation_properties
  (org_id,module,property_type,name,description,address,city,amenities)
select id,'stay','service_apartment','Lakeview Service Apartments','Serviced apartments for short and extended stays.','HITEC City','Hyderabad',array['Wi-Fi','Kitchen','Parking','Air conditioning']
from public.organizations where name='Demo Venues'
on conflict do nothing;

insert into public.accommodation_units
  (property_id,name,occupancy_type,capacity,inventory,rent_monthly,deposit,amenities)
select id,'Double Sharing','double',2,8,12500,12500,array['Wardrobe','Study desk','Attached bath']
from public.accommodation_properties where name='UrbanNest Co-Living'
on conflict do nothing;

insert into public.accommodation_units
  (property_id,name,occupancy_type,capacity,inventory,price_nightly,amenities)
select id,'Studio Room','studio',2,5,2800,array['Queen bed','Kitchenette','Workspace']
from public.accommodation_properties where name='Lakeview Service Apartments'
on conflict do nothing;

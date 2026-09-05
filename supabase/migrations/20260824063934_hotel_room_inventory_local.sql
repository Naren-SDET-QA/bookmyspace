-- Local-only hotel room inventory foundation.
-- This migration is additive and intentionally does not alter venue-slot tables.

create table if not exists public.hotel_room_types (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.venues(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  capacity integer not null check (capacity > 0),
  bed_type text not null,
  quantity integer not null check (quantity > 0),
  amenities jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (venue_id, slug)
);

create table if not exists public.hotel_room_images (
  id uuid primary key default gen_random_uuid(),
  room_type_id uuid not null references public.hotel_room_types(id) on delete cascade,
  url text not null,
  alt_text text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.hotel_room_availability (
  room_type_id uuid not null references public.hotel_room_types(id) on delete cascade,
  stay_date date not null,
  available_quantity integer not null check (available_quantity >= 0),
  price_amount numeric not null check (price_amount >= 0),
  currency text not null default 'INR',
  updated_at timestamptz not null default now(),
  primary key (room_type_id, stay_date)
);

create table if not exists public.hotel_room_holds (
  id uuid primary key default gen_random_uuid(),
  room_type_id uuid not null references public.hotel_room_types(id),
  user_id uuid not null references auth.users(id),
  check_in date not null,
  check_out date not null,
  quantity integer not null check (quantity > 0),
  idempotency_key uuid not null unique,
  status text not null default 'active' check (status in ('active','confirmed','released','expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (check_out > check_in)
);

create index if not exists hotel_room_types_venue_active_idx
  on public.hotel_room_types (venue_id, is_active);
create index if not exists hotel_room_availability_date_idx
  on public.hotel_room_availability (stay_date, room_type_id);
create index if not exists hotel_room_holds_active_dates_idx
  on public.hotel_room_holds (room_type_id, check_in, check_out)
  where status = 'active';

alter table public.hotel_room_types enable row level security;
alter table public.hotel_room_images enable row level security;
alter table public.hotel_room_availability enable row level security;
alter table public.hotel_room_holds enable row level security;

drop policy if exists hotel_room_types_public_read on public.hotel_room_types;
create policy hotel_room_types_public_read on public.hotel_room_types
  for select to anon, authenticated using (is_active);
drop policy if exists hotel_room_images_public_read on public.hotel_room_images;
create policy hotel_room_images_public_read on public.hotel_room_images
  for select to anon, authenticated using (exists (
    select 1 from public.hotel_room_types rt
    where rt.id = room_type_id and rt.is_active
  ));
drop policy if exists hotel_room_availability_public_read on public.hotel_room_availability;
create policy hotel_room_availability_public_read on public.hotel_room_availability
  for select to anon, authenticated using (true);
drop policy if exists hotel_room_holds_owner_read on public.hotel_room_holds;
create policy hotel_room_holds_owner_read on public.hotel_room_holds
  for select to authenticated using ((select auth.uid()) = user_id);

create or replace function public.available_hotel_rooms(
  p_venue_id uuid,
  p_check_in date,
  p_check_out date
)
returns table (
  room_type_id uuid,
  name text,
  capacity integer,
  bed_type text,
  available_quantity integer,
  price_amount numeric,
  currency text
)
language sql stable security invoker
set search_path = public
as $$
  select rt.id, rt.name, rt.capacity, rt.bed_type,
    least(rt.quantity, min(ra.available_quantity)) as available_quantity,
    max(ra.price_amount) as price_amount,
    max(ra.currency) as currency
  from public.hotel_room_types rt
  join public.hotel_room_availability ra on ra.room_type_id = rt.id
  where rt.venue_id = p_venue_id
    and rt.is_active
    and ra.stay_date >= p_check_in
    and ra.stay_date < p_check_out
  group by rt.id, rt.name, rt.capacity, rt.bed_type, rt.quantity
  having count(*) = (p_check_out - p_check_in)
     and min(ra.available_quantity) > 0
  order by rt.name;
$$;

create or replace function public.acquire_hotel_room_hold(
  p_room_type_id uuid,
  p_user_id uuid,
  p_check_in date,
  p_check_out date,
  p_quantity integer,
  p_idempotency_key uuid,
  p_hold_minutes integer default 10
)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_existing public.hotel_room_holds;
  v_date date;
  v_price numeric;
  v_lock bigint;
begin
  if p_user_id is null or (select auth.uid()) is distinct from p_user_id
     or p_quantity < 1 or p_check_out <= p_check_in then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_REQUEST');
  end if;

  select * into v_existing from public.hotel_room_holds
  where idempotency_key = p_idempotency_key;
  if found and v_existing.status = 'active' and v_existing.expires_at > now() then
    return jsonb_build_object('success', true, 'hold_id', v_existing.id, 'status', 'HELD');
  end if;

  perform public.expire_hotel_room_holds();
  v_lock := hashtextextended(p_room_type_id::text || ':' || p_check_in::text || ':' || p_check_out::text, 0);
  perform pg_advisory_xact_lock(v_lock);

  if exists (
    select 1 from public.hotel_room_availability ra
    where ra.room_type_id = p_room_type_id
      and ra.stay_date >= p_check_in and ra.stay_date < p_check_out
      and ra.available_quantity < p_quantity
  ) or exists (
    select 1 from public.hotel_room_holds h
    where h.room_type_id = p_room_type_id and h.status = 'active'
      and h.expires_at > now() and h.check_in < p_check_out and h.check_out > p_check_in
      and h.quantity + p_quantity > (
        select rt.quantity from public.hotel_room_types rt where rt.id = p_room_type_id
      )
  ) then
    return jsonb_build_object('success', false, 'error_code', 'ROOM_UNAVAILABLE');
  end if;

  select max(price_amount) into v_price from public.hotel_room_availability
  where room_type_id = p_room_type_id and stay_date >= p_check_in and stay_date < p_check_out;
  if v_price is null then
    return jsonb_build_object('success', false, 'error_code', 'ROOM_DATES_UNAVAILABLE');
  end if;

  insert into public.hotel_room_holds(room_type_id,user_id,check_in,check_out,quantity,idempotency_key,expires_at)
  values (p_room_type_id,p_user_id,p_check_in,p_check_out,p_quantity,p_idempotency_key,
          now() + (p_hold_minutes * interval '1 minute'))
  returning id into v_existing.id;

  v_date := p_check_in;
  while v_date < p_check_out loop
    update public.hotel_room_availability
    set available_quantity = available_quantity - p_quantity, updated_at = now()
    where room_type_id = p_room_type_id and stay_date = v_date;
    v_date := v_date + 1;
  end loop;
  return jsonb_build_object('success', true, 'hold_id', v_existing.id, 'status', 'HELD', 'price_amount', v_price);
end;
$$;

create or replace function public.expire_hotel_room_holds()
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare h record; d date; n integer := 0;
begin
  for h in select * from public.hotel_room_holds where status = 'active' and expires_at <= now() loop
    d := h.check_in;
    while d < h.check_out loop
      update public.hotel_room_availability set available_quantity = available_quantity + h.quantity, updated_at = now()
      where room_type_id = h.room_type_id and stay_date = d;
      d := d + 1;
    end loop;
    update public.hotel_room_holds set status = 'expired' where id = h.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

create or replace function public.release_hotel_room_hold(p_hold_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare h public.hotel_room_holds; d date;
begin
  if (select auth.uid()) is distinct from p_user_id then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  select * into h from public.hotel_room_holds where id = p_hold_id and user_id = p_user_id and status = 'active' for update;
  if not found then return jsonb_build_object('success', false, 'error_code', 'HOLD_NOT_FOUND'); end if;
  d := h.check_in;
  while d < h.check_out loop
    update public.hotel_room_availability set available_quantity = available_quantity + h.quantity, updated_at = now()
    where room_type_id = h.room_type_id and stay_date = d;
    d := d + 1;
  end loop;
  update public.hotel_room_holds set status = 'released' where id = h.id;
  return jsonb_build_object('success', true, 'hold_id', h.id, 'status', 'RELEASED');
end;
$$;

revoke all on function public.acquire_hotel_room_hold(uuid,uuid,date,date,integer,uuid,integer) from public;
grant execute on function public.acquire_hotel_room_hold(uuid,uuid,date,date,integer,uuid,integer) to authenticated;
revoke all on function public.release_hotel_room_hold(uuid,uuid) from public;
grant execute on function public.release_hotel_room_hold(uuid,uuid) to authenticated;
grant execute on function public.available_hotel_rooms(uuid,date,date) to anon, authenticated;

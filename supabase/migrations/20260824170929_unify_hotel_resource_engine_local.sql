-- Local-only Phase 6.7C. Hotel room inventory is mutated by the unified
-- resource hold path below. Legacy hotel rows are retained as compatibility
-- mirrors and never perform an independent inventory mutation.

alter table public.booking_holds
  add column if not exists quantity integer not null default 1;
alter table public.booking_holds
  drop constraint if exists booking_holds_quantity_ck;
alter table public.booking_holds
  add constraint booking_holds_quantity_ck check (quantity > 0);

alter table public.hotel_room_holds
  add column if not exists booking_hold_id uuid references public.booking_holds(id) on delete restrict;
create unique index if not exists hotel_room_holds_booking_hold_idx
  on public.hotel_room_holds(booking_hold_id)
  where booking_hold_id is not null;

create unique index if not exists bookable_resources_hotel_room_unique_idx
  on public.bookable_resources(external_reference)
  where resource_type = 'hotel_room_type' and external_reference is not null;

create or replace function public.acquire_resource_hold(
  p_resource_id uuid,
  p_check_in date,
  p_check_out date,
  p_quantity integer,
  p_idempotency_key uuid,
  p_hold_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_resource public.bookable_resources;
  v_room public.hotel_room_types;
  v_hold public.booking_holds;
  v_legacy_id uuid;
  v_date date;
  v_total numeric;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  if p_check_in is null or p_check_out <= p_check_in or p_quantity < 1
     or p_hold_minutes < 1 or p_hold_minutes > 60 or p_idempotency_key is null then
    return jsonb_build_object('success', false, 'error_code', 'INVALID_REQUEST');
  end if;

  select * into v_resource from public.bookable_resources
  where id = p_resource_id and active for update;
  if not found or v_resource.resource_type <> 'hotel_room_type'
     or v_resource.external_reference is null then
    return jsonb_build_object('success', false, 'error_code', 'RESOURCE_UNAVAILABLE');
  end if;
  if not public.runtime_feature_enabled_for_venue(v_resource.venue_id, 'hotel') then
    return jsonb_build_object('success', false, 'error_code', 'FEATURE_DISABLED');
  end if;

  select * into v_hold from public.booking_holds
  where idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('success', true, 'hold_id', v_hold.id,
      'status', upper(v_hold.status), 'idempotent', true);
  end if;

  select * into v_room from public.hotel_room_types
  where id = v_resource.external_reference and venue_id = v_resource.venue_id and is_active
  for update;
  if not found then
    return jsonb_build_object('success', false, 'error_code', 'RESOURCE_UNAVAILABLE');
  end if;

  perform public.expire_hotel_room_holds();
  if exists (
    select 1 from public.hotel_room_availability a
    where a.room_type_id = v_room.id and a.stay_date >= p_check_in
      and a.stay_date < p_check_out and a.available_quantity < p_quantity
  ) or not exists (
    select 1 from public.hotel_room_availability a
    where a.room_type_id = v_room.id and a.stay_date >= p_check_in
      and a.stay_date < p_check_out
    having count(*) = (p_check_out - p_check_in)
  ) then
    return jsonb_build_object('success', false, 'error_code', 'ROOM_UNAVAILABLE');
  end if;

  select sum(a.price_amount * p_quantity) into v_total
  from public.hotel_room_availability a
  where a.room_type_id = v_room.id and a.stay_date >= p_check_in and a.stay_date < p_check_out;

  insert into public.booking_holds(
    idempotency_key, venue_id, slot_id, book_date, user_id, price_amount,
    expires_at, status, quantity, resource_id, resource_start_at, resource_end_at
  ) values (
    p_idempotency_key, v_resource.venue_id, null, p_check_in, v_uid, v_total,
    now() + (p_hold_minutes * interval '1 minute'), 'active', p_quantity,
    p_resource_id, p_check_in::timestamptz, p_check_out::timestamptz
  ) returning * into v_hold;

  v_date := p_check_in;
  while v_date < p_check_out loop
    update public.hotel_room_availability
    set available_quantity = available_quantity - p_quantity, updated_at = now()
    where room_type_id = v_room.id and stay_date = v_date;
    v_date := v_date + 1;
  end loop;

  insert into public.hotel_room_holds(
    room_type_id, user_id, check_in, check_out, quantity, idempotency_key,
    status, expires_at, booking_hold_id
  ) values (
    v_room.id, v_uid, p_check_in, p_check_out, p_quantity, p_idempotency_key,
    'active', v_hold.expires_at, v_hold.id
  ) returning id into v_legacy_id;

  return jsonb_build_object('success', true, 'hold_id', v_hold.id,
    'legacy_hold_id', v_legacy_id, 'status', 'HELD', 'price_amount', v_total);
end;
$$;

create or replace function public.release_resource_hold(p_hold_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  h public.booking_holds;
  v_date date;
begin
  select * into h from public.booking_holds
  where id = p_hold_id and user_id = v_uid for update;
  if not found then return jsonb_build_object('success', false, 'error_code', 'HOLD_NOT_FOUND'); end if;
  if h.status <> 'active' then
    return jsonb_build_object('success', true, 'hold_id', h.id, 'status', upper(h.status), 'idempotent', true);
  end if;
  if h.resource_id is null then
    update public.booking_holds set status = 'released' where id = h.id;
    return jsonb_build_object('success', true, 'hold_id', h.id, 'status', 'RELEASED');
  end if;
  if exists (select 1 from public.bookable_resources r where r.id = h.resource_id and r.resource_type = 'hotel_room_type') then
    v_date := h.resource_start_at::date;
    while v_date < h.resource_end_at::date loop
      update public.hotel_room_availability a
      set available_quantity = a.available_quantity + h.quantity, updated_at = now()
      from public.bookable_resources r
      where r.id = h.resource_id and a.room_type_id = r.external_reference and a.stay_date = v_date;
      v_date := v_date + 1;
    end loop;
    update public.hotel_room_holds set status = 'released' where booking_hold_id = h.id and status = 'active';
  end if;
  update public.booking_holds set status = 'released' where id = h.id;
  return jsonb_build_object('success', true, 'hold_id', h.id, 'status', 'RELEASED');
end;
$$;

create or replace function public.create_resource_booking(p_hold_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  h public.booking_holds;
  b public.bookings;
begin
  select * into h from public.booking_holds where id = p_hold_id and user_id = auth.uid() for update;
  if not found then return jsonb_build_object('success', false, 'error_code', 'HOLD_NOT_FOUND'); end if;
  if h.status <> 'active' or h.expires_at <= now() then
    return jsonb_build_object('success', false, 'error_code', 'HOLD_EXPIRED');
  end if;
  select * into b from public.bookings where hold_id = h.id limit 1;
  if found then return jsonb_build_object('success', true, 'booking_id', b.id, 'idempotent', true); end if;
  insert into public.bookings(
    booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
    hold_id, status, quantity, amount, currency, tax_amount, discount_amount, total_amount,
    resource_id, resource_start_at, resource_end_at, metadata
  ) values (
    'BMS-R-' || replace(left(gen_random_uuid()::text, 18), '-', ''), h.user_id, h.venue_id,
    null, h.book_date, null, null, h.id, 'pending', h.quantity, h.price_amount, 'INR',
    0, 0, h.price_amount, h.resource_id, h.resource_start_at, h.resource_end_at,
    jsonb_build_object('resource_booking', true)
  ) returning * into b;
  update public.booking_holds set status = 'confirmed' where id = h.id;
  update public.hotel_room_holds set status = 'confirmed' where booking_hold_id = h.id;
  return jsonb_build_object('success', true, 'booking_id', b.id, 'status', 'PENDING');
end;
$$;

revoke all on function public.acquire_resource_hold(uuid,date,date,integer,uuid,integer) from public;
grant execute on function public.acquire_resource_hold(uuid,date,date,integer,uuid,integer) to authenticated;
revoke all on function public.release_resource_hold(uuid) from public;
grant execute on function public.release_resource_hold(uuid) to authenticated;
revoke all on function public.create_resource_booking(uuid) from public;
grant execute on function public.create_resource_booking(uuid) to authenticated;

create or replace function public.expire_resource_holds()
returns integer language plpgsql security definer
set search_path = public, pg_temp
as $$
declare h record; d date; n integer := 0;
begin
  for h in
    select bh.*, r.external_reference as room_type_id
    from public.booking_holds bh
    join public.bookable_resources r on r.id = bh.resource_id
    where bh.resource_id is not null and r.resource_type = 'hotel_room_type'
      and bh.status = 'active' and bh.expires_at <= now()
    for update of bh
  loop
    d := h.resource_start_at::date;
    while d < h.resource_end_at::date loop
      update public.hotel_room_availability
      set available_quantity = available_quantity + h.quantity, updated_at = now()
      where room_type_id = h.room_type_id and stay_date = d;
      d := d + 1;
    end loop;
    update public.hotel_room_holds set status = 'expired'
      where booking_hold_id = h.id and status = 'active';
    update public.booking_holds set status = 'expired' where id = h.id;
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Re-point the generic path at the unified expiration ledger. Legacy rows
-- without booking_hold_id remain handled by the compatibility function below.
create or replace function public.acquire_hotel_room_hold(
  p_room_type_id uuid, p_user_id uuid, p_check_in date, p_check_out date,
  p_quantity integer, p_idempotency_key uuid, p_hold_minutes integer default 10
)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_resource uuid; v_result jsonb;
begin
  if auth.uid() is distinct from p_user_id then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  insert into public.bookable_resources(resource_type, venue_id, category_id, organization_id, external_reference)
  select 'hotel_room_type', v.id, v.category_id, v.org_id, rt.id
  from public.hotel_room_types rt join public.venues v on v.id = rt.venue_id
  where rt.id = p_room_type_id
  on conflict (external_reference) where resource_type = 'hotel_room_type' and external_reference is not null
  do update set updated_at = now()
  returning id into v_resource;
  select id into v_resource from public.bookable_resources
  where resource_type = 'hotel_room_type' and external_reference = p_room_type_id;
  v_result := public.acquire_resource_hold(v_resource, p_check_in, p_check_out,
    p_quantity, p_idempotency_key, p_hold_minutes);
  if coalesce((v_result->>'success')::boolean, false) then
    return v_result || jsonb_build_object('hold_id', v_result->'legacy_hold_id');
  end if;
  return v_result;
end;
$$;

create or replace function public.release_hotel_room_hold(p_hold_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_booking_hold uuid;
begin
  if auth.uid() is distinct from p_user_id then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  select booking_hold_id into v_booking_hold from public.hotel_room_holds
  where id = p_hold_id and user_id = p_user_id;
  if v_booking_hold is not null then
    return public.release_resource_hold(v_booking_hold);
  end if;
  return jsonb_build_object('success', false, 'error_code', 'HOLD_NOT_FOUND');
end;
$$;

create or replace function public.expire_hotel_room_holds()
returns integer language plpgsql security definer
set search_path = public, pg_temp
as $$
declare h record; d date; n integer := 0;
begin
  n := public.expire_resource_holds();
  for h in select * from public.hotel_room_holds
    where booking_hold_id is null and status = 'active' and expires_at <= now()
  loop
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

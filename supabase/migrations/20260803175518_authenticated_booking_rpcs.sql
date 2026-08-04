create or replace function public.acquire_booking_hold_for_current_user(
  p_venue_id uuid,
  p_slot_id uuid,
  p_book_date date,
  p_idempotency_key uuid,
  p_hold_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_price numeric;
  v_hold_id uuid;
  v_minutes integer := least(greatest(coalesce(p_hold_minutes, 10), 1), 30);
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select s.price_amount into v_price
  from public.time_slots s
  join public.venues v on v.id = s.venue_id
  where s.id = p_slot_id
    and s.venue_id = p_venue_id
    and s.is_active
    and v.is_active
    and v.deleted_at is null;

  if not found then
    raise exception 'invalid slot' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.venue_blocked_dates b
    where b.venue_id = p_venue_id and b.blocked_date = p_book_date
  ) or not exists (
    select 1 from public.venue_operating_hours oh
    where oh.venue_id = p_venue_id
      and oh.day_of_week = ((extract(dow from p_book_date)::int + 6) % 7)::smallint
      and not oh.is_closed
  ) then
    raise exception 'slot unavailable' using errcode = 'P0001';
  end if;

  v_hold_id := public.acquire_booking_hold(
    p_venue_id, p_slot_id, p_book_date, v_user_id,
    p_idempotency_key, v_price, v_minutes
  );
  return jsonb_build_object(
    'hold_id', v_hold_id,
    'expires_in_minutes', v_minutes
  );
end;
$$;

create or replace function public.create_booking_from_hold_for_current_user(
  p_hold_id uuid,
  p_booking_ref text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  return public.create_booking_from_hold(p_hold_id, v_user_id, p_booking_ref);
end;
$$;

revoke all on function public.acquire_booking_hold_for_current_user(uuid, uuid, date, uuid, integer) from public;
revoke all on function public.create_booking_from_hold_for_current_user(uuid, text) from public;
grant execute on function public.acquire_booking_hold_for_current_user(uuid, uuid, date, uuid, integer) to authenticated;
grant execute on function public.create_booking_from_hold_for_current_user(uuid, text) to authenticated;

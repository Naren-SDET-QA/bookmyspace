-- Create a booking from an authenticated user's active hold in one transaction.
-- Only the service role (the create-booking Edge Function) may execute this.
create or replace function public.create_booking_from_hold(
  p_hold_id uuid,
  p_user_id uuid,
  p_booking_ref text
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_hold public.booking_holds%rowtype;
  v_slot public.time_slots%rowtype;
  v_tax_rate numeric;
  v_tax numeric;
  v_total numeric;
  v_booking_id uuid;
  v_status public.booking_status;
begin
  select * into v_hold
  from public.booking_holds
  where id = p_hold_id
  for update;

  if not found or v_hold.user_id <> p_user_id then
    raise exception 'invalid hold' using errcode = '22023';
  end if;
  if v_hold.status <> 'active' or v_hold.expires_at <= now() then
    raise exception 'hold expired' using errcode = 'P0001';
  end if;

  select * into v_slot
  from public.time_slots
  where id = v_hold.slot_id
    and venue_id = v_hold.venue_id
    and is_active;

  if not found or v_slot.price_amount <> v_hold.price_amount then
    raise exception 'invalid slot price' using errcode = '22023';
  end if;

  select tax_rate into v_tax_rate
  from public.venues
  where id = v_hold.venue_id and is_active and deleted_at is null;

  if not found then
    raise exception 'venue unavailable' using errcode = '22023';
  end if;

  v_tax := round(v_slot.price_amount * v_tax_rate / 100, 2);
  v_total := v_slot.price_amount + v_tax;
  v_status := case when v_total = 0 then 'confirmed'::public.booking_status
                   else 'pending'::public.booking_status end;

  insert into public.bookings (
    booking_ref, user_id, venue_id, slot_id, book_date,
    start_time, end_time, hold_id, status, quantity,
    amount, tax_amount, total_amount, currency, confirmed_at
  ) values (
    p_booking_ref, p_user_id, v_hold.venue_id, v_slot.id, v_hold.book_date,
    v_slot.start_time, v_slot.end_time, v_hold.id, v_status, 1,
    v_slot.price_amount, v_tax, v_total, 'INR',
    case when v_status = 'confirmed' then now() else null end
  ) returning id into v_booking_id;

  update public.booking_holds set status = 'confirmed' where id = v_hold.id;
  return v_booking_id;
end;
$$;

revoke all on function public.create_booking_from_hold(uuid, uuid, text) from public;
grant execute on function public.create_booking_from_hold(uuid, uuid, text) to service_role;

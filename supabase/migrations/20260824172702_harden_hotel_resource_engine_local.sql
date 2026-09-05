-- Additive local hardening: no booking-time mapping creation and safe
-- concurrent idempotency handling.
create or replace function public.acquire_resource_hold(
  p_resource_id uuid, p_check_in date, p_check_out date, p_quantity integer,
  p_idempotency_key uuid, p_hold_minutes integer default 10
)
returns jsonb language plpgsql security definer set search_path = public, pg_temp
as $$
declare v_uid uuid := auth.uid(); v_resource public.bookable_resources;
  v_room public.hotel_room_types; v_hold public.booking_holds; v_date date; v_total numeric;
begin
  if v_uid is null then return jsonb_build_object('success',false,'error_code','UNAUTHORIZED'); end if;
  if p_check_in is null or p_check_out <= p_check_in or p_quantity < 1
     or p_hold_minutes < 1 or p_hold_minutes > 60 or p_idempotency_key is null then
    return jsonb_build_object('success',false,'error_code','INVALID_REQUEST');
  end if;
  select * into v_resource from public.bookable_resources where id=p_resource_id and active for update;
  if not found or v_resource.resource_type <> 'hotel_room_type' or v_resource.external_reference is null then
    return jsonb_build_object('success',false,'error_code','RESOURCE_UNAVAILABLE');
  end if;
  if not public.runtime_feature_enabled_for_venue(v_resource.venue_id,'hotel') then
    return jsonb_build_object('success',false,'error_code','FEATURE_DISABLED');
  end if;
  select * into v_hold from public.booking_holds where idempotency_key=p_idempotency_key;
  if found then return jsonb_build_object('success',true,'hold_id',v_hold.id,'status',upper(v_hold.status),'idempotent',true); end if;
  select * into v_room from public.hotel_room_types where id=v_resource.external_reference
    and venue_id=v_resource.venue_id and is_active for update;
  if not found then return jsonb_build_object('success',false,'error_code','RESOURCE_UNAVAILABLE'); end if;
  perform public.expire_hotel_room_holds();
  if exists (select 1 from public.hotel_room_availability a where a.room_type_id=v_room.id
    and a.stay_date>=p_check_in and a.stay_date<p_check_out and a.available_quantity<p_quantity)
    or not exists (select 1 from public.hotel_room_availability a where a.room_type_id=v_room.id
      and a.stay_date>=p_check_in and a.stay_date<p_check_out having count(*)=(p_check_out-p_check_in)) then
    return jsonb_build_object('success',false,'error_code','ROOM_UNAVAILABLE');
  end if;
  select sum(a.price_amount*p_quantity) into v_total from public.hotel_room_availability a
    where a.room_type_id=v_room.id and a.stay_date>=p_check_in and a.stay_date<p_check_out;
  insert into public.booking_holds(idempotency_key,venue_id,slot_id,book_date,user_id,price_amount,expires_at,status,quantity,resource_id,resource_start_at,resource_end_at)
  values(p_idempotency_key,v_resource.venue_id,null,p_check_in,v_uid,v_total,now()+(p_hold_minutes*interval '1 minute'),'active',p_quantity,p_resource_id,p_check_in::timestamptz,p_check_out::timestamptz)
  on conflict(idempotency_key) do nothing returning * into v_hold;
  if not found then
    select * into v_hold from public.booking_holds where idempotency_key=p_idempotency_key;
    return jsonb_build_object('success',true,'hold_id',v_hold.id,'status',upper(v_hold.status),'idempotent',true);
  end if;
  v_date:=p_check_in;
  while v_date<p_check_out loop
    update public.hotel_room_availability set available_quantity=available_quantity-p_quantity,updated_at=now()
      where room_type_id=v_room.id and stay_date=v_date;
    v_date:=v_date+1;
  end loop;
  insert into public.hotel_room_holds(room_type_id,user_id,check_in,check_out,quantity,idempotency_key,status,expires_at,booking_hold_id)
  values(v_room.id,v_uid,p_check_in,p_check_out,p_quantity,p_idempotency_key,'active',v_hold.expires_at,v_hold.id);
  return jsonb_build_object('success',true,'hold_id',v_hold.id,'status','HELD','price_amount',v_total);
end; $$;

create or replace function public.acquire_hotel_room_hold(
  p_room_type_id uuid,p_user_id uuid,p_check_in date,p_check_out date,p_quantity integer,
  p_idempotency_key uuid,p_hold_minutes integer default 10
)
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare v_resource uuid; v_result jsonb;
begin
  if auth.uid() is distinct from p_user_id then return jsonb_build_object('success',false,'error_code','UNAUTHORIZED'); end if;
  select id into v_resource from public.bookable_resources
    where resource_type='hotel_room_type' and external_reference=p_room_type_id and active;
  if v_resource is null then return jsonb_build_object('success',false,'error_code','RESOURCE_MAPPING_MISSING'); end if;
  v_result:=public.acquire_resource_hold(v_resource,p_check_in,p_check_out,p_quantity,p_idempotency_key,p_hold_minutes);
  return v_result;
end; $$;

revoke all on function public.acquire_resource_hold(uuid,date,date,integer,uuid,integer) from public;
grant execute on function public.acquire_resource_hold(uuid,date,date,integer,uuid,integer) to authenticated;

-- Phase 6.7C contract checks. Run against local Supabase only.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'booking_holds'
      and column_name = 'quantity'
  ) then
    raise exception 'booking_holds.quantity is required for resource holds';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'hotel_room_holds'
      and column_name = 'booking_hold_id'
  ) then
    raise exception 'hotel_room_holds.booking_hold_id compatibility link is required';
  end if;

  if to_regprocedure('public.acquire_resource_hold(uuid,date,date,integer,uuid,integer)') is null then
    raise exception 'generic acquire_resource_hold RPC is required';
  end if;

  if to_regprocedure('public.release_resource_hold(uuid)') is null then
    raise exception 'generic release_resource_hold RPC is required';
  end if;

  if to_regprocedure('public.create_resource_booking(uuid)') is null then
    raise exception 'generic create_resource_booking RPC is required';
  end if;

  if position('insert into public.bookable_resources' in lower(
    pg_get_functiondef('public.acquire_hotel_room_hold(uuid,uuid,date,date,integer,uuid,integer)'::regprocedure)
  )) > 0 then
    raise exception 'legacy hotel booking must not create resource mappings';
  end if;

  if position('on conflict' in lower(
    pg_get_functiondef('public.acquire_resource_hold(uuid,date,date,integer,uuid,integer)'::regprocedure)
  )) = 0 then
    raise exception 'resource hold must handle concurrent idempotency conflicts';
  end if;
end $$;

-- Local-only additive compatibility wrappers for tenant-aware operations.
-- Existing RPC signatures and behavior are intentionally unchanged.

create or replace function public.resolve_tenant_context(p_venue_id uuid)
returns jsonb
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select case when v.id is null then null else jsonb_build_object(
    'user_id', auth.uid(),
    'organization_id', v.org_id,
    'venue_id', v.id,
    'category_id', v.category_id,
    'role', coalesce((select ur.role::text from public.user_roles ur
                     where ur.user_id = auth.uid() and ur.revoked_at is null
                     limit 1), 'customer'),
    'configuration_version', coalesce((select oc.configuration_version
      from public.organization_configurations oc where oc.organization_id = v.org_id), 0)
  ) end
  from public.venues v
  where v.id = p_venue_id;
$$;

create or replace function public.runtime_feature_enabled_for_venue(
  p_venue_id uuid,
  p_feature text
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  v_org uuid;
  v_category uuid;
  v_enabled boolean := true;
  v_config jsonb;
begin
  select org_id, category_id into v_org, v_category
  from public.venues where id = p_venue_id and is_active = true;
  if v_org is null then return false; end if;

  select features into v_config
  from public.organization_configurations
  where organization_id = v_org;
  if v_config ? p_feature then
    v_enabled := coalesce((v_config ->> p_feature)::boolean, false);
  end if;

  if v_category is not null then
    if exists (select 1 from public.venue_categories c
               where c.id = v_category
                 and coalesce((c.metadata->>'active')::boolean, true) = false) then
      return false;
    end if;
    if exists (
      select 1 from public.organization_category_configurations cc
      where cc.organization_id = v_org and cc.category_id = v_category
        and ((cc.configuration ? 'enabled' and coalesce((cc.configuration->>'enabled')::boolean, false) = false)
          or (cc.configuration ? 'bookable' and coalesce((cc.configuration->>'bookable')::boolean, false) = false))
    ) then return false; end if;
  end if;
  return v_enabled;
exception when invalid_text_representation then
  return false;
end;
$$;

create or replace function public.acquire_booking_hold_with_tenant(
  p_venue_id uuid, p_slot_id uuid, p_book_date date, p_user_id uuid,
  p_idempotency_key uuid, p_amount numeric, p_hold_minutes integer default 10
)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    raise exception 'authenticated user mismatch' using errcode = '42501';
  end if;
  if not public.runtime_feature_enabled_for_venue(p_venue_id, 'booking') then
    raise exception 'FEATURE_DISABLED' using errcode = 'P0001', detail = 'feature=booking';
  end if;
  return public.acquire_booking_hold(p_venue_id, p_slot_id, p_book_date, p_user_id,
    p_idempotency_key, p_amount, p_hold_minutes);
end;
$$;

create or replace function public.confirm_booking_with_tenant(p_booking_id uuid, p_payment_ref text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_venue uuid;
begin
  if auth.uid() is null then raise exception 'authenticated session required' using errcode = '42501'; end if;
  select venue_id into v_venue from public.bookings where id = p_booking_id and user_id = auth.uid();
  if v_venue is null then raise exception 'booking not found or unauthorized' using errcode = '42501'; end if;
  if not public.runtime_feature_enabled_for_venue(v_venue, 'booking') then
    raise exception 'FEATURE_DISABLED' using errcode = 'P0001', detail = 'feature=booking';
  end if;
  perform public.confirm_booking(p_booking_id, p_payment_ref);
end;
$$;

create or replace function public.confirm_venue_booking_with_tenant(
  p_booking_id uuid, p_user_id uuid, p_payment_ref text, p_payment_method text default 'UPIRazorpay'
)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_venue uuid;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  select venue_id into v_venue from public.bookings where id = p_booking_id and user_id = auth.uid();
  if v_venue is null then return jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND'); end if;
  if not public.runtime_feature_enabled_for_venue(v_venue, 'booking') then
    return jsonb_build_object('success', false, 'error_code', 'FEATURE_DISABLED', 'feature', 'booking');
  end if;
  return public.confirm_venue_booking(p_booking_id, p_user_id, p_payment_ref, p_payment_method);
end;
$$;

create or replace function public.available_hotel_rooms_with_tenant(
  p_venue_id uuid, p_check_in date, p_check_out date
)
returns table(room_type_id uuid, name text, capacity integer, bed_type text,
  available_quantity integer, price_amount numeric, currency text)
language plpgsql security invoker set search_path = public as $$
begin
  if not public.runtime_feature_enabled_for_venue(p_venue_id, 'hotel_room_booking') then
    return;
  end if;
  return query select * from public.available_hotel_rooms(p_venue_id, p_check_in, p_check_out);
end;
$$;

create or replace function public.acquire_hotel_room_hold_with_tenant(
  p_room_type_id uuid, p_user_id uuid, p_check_in date, p_check_out date,
  p_quantity integer, p_idempotency_key uuid, p_hold_minutes integer default 10
)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_venue uuid;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  select venue_id into v_venue from public.hotel_room_types where id = p_room_type_id and is_active = true;
  if v_venue is null or not public.runtime_feature_enabled_for_venue(v_venue, 'hotel_room_booking') then
    return jsonb_build_object('success', false, 'error_code', 'FEATURE_DISABLED', 'feature', 'hotel_room_booking');
  end if;
  return public.acquire_hotel_room_hold(p_room_type_id, p_user_id, p_check_in, p_check_out,
    p_quantity, p_idempotency_key, p_hold_minutes);
end;
$$;

create or replace function public.release_hotel_room_hold_with_tenant(p_hold_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare v_venue uuid;
begin
  if auth.uid() is null or p_user_id is distinct from auth.uid() then
    return jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  end if;
  select rt.venue_id into v_venue from public.hotel_room_holds h
    join public.hotel_room_types rt on rt.id = h.room_type_id
    where h.id = p_hold_id and h.user_id = auth.uid();
  if v_venue is null then return jsonb_build_object('success', false, 'error_code', 'HOLD_NOT_FOUND'); end if;
  if not public.runtime_feature_enabled_for_venue(v_venue, 'hotel_room_booking') then
    return jsonb_build_object('success', false, 'error_code', 'FEATURE_DISABLED', 'feature', 'hotel_room_booking');
  end if;
  return public.release_hotel_room_hold(p_hold_id, p_user_id);
end;
$$;

revoke all on function public.resolve_tenant_context(uuid), public.runtime_feature_enabled_for_venue(uuid,text) from public, anon;
grant execute on function public.resolve_tenant_context(uuid), public.runtime_feature_enabled_for_venue(uuid,text) to authenticated, service_role;
revoke all on function public.acquire_booking_hold_with_tenant(uuid,uuid,date,uuid,uuid,numeric,integer), public.confirm_booking_with_tenant(uuid,text), public.confirm_venue_booking_with_tenant(uuid,uuid,text,text) from public, anon;
grant execute on function public.acquire_booking_hold_with_tenant(uuid,uuid,date,uuid,uuid,numeric,integer), public.confirm_booking_with_tenant(uuid,text), public.confirm_venue_booking_with_tenant(uuid,uuid,text,text) to authenticated, service_role;
revoke all on function public.acquire_hotel_room_hold_with_tenant(uuid,uuid,date,date,integer,uuid,integer), public.release_hotel_room_hold_with_tenant(uuid,uuid) from public, anon;
grant execute on function public.acquire_hotel_room_hold_with_tenant(uuid,uuid,date,date,integer,uuid,integer), public.release_hotel_room_hold_with_tenant(uuid,uuid) to authenticated, service_role;
revoke all on function public.available_hotel_rooms_with_tenant(uuid,date,date) from public;
grant execute on function public.available_hotel_rooms_with_tenant(uuid,date,date) to anon, authenticated, service_role;

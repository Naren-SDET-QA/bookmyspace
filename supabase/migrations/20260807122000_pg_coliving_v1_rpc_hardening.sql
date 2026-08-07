-- PG V1 RPC hardening: workflow-trigger bypass and client idempotency.

create or replace function public.submit_pg_property(p_property_id uuid)
returns public.accommodation_properties language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.accommodation_properties;
begin
  perform set_config('app.pg_approval_workflow','true',true);
  update public.accommodation_properties p set approval_status='pending',submitted_at=now(),approval_notes=null
  from public.organizations o
  where p.id=p_property_id and p.module='pg' and p.org_id=o.id and o.owner_user_id=auth.uid()
  returning p.* into v;
  if v.id is null then raise exception 'property not found or not owner'; end if;
  return v;
end;
$$;
revoke all on function public.submit_pg_property(uuid) from public,anon;
grant execute on function public.submit_pg_property(uuid) to authenticated;

create or replace function public.decide_pg_property(p_property_id uuid,p_approve boolean,p_notes text default null)
returns public.accommodation_properties language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.accommodation_properties;
begin
  if not public.has_role(auth.uid(),'administrator') and not public.has_role(auth.uid(),'super_administrator') then
    raise exception 'admin required' using errcode='42501';
  end if;
  perform set_config('app.pg_approval_workflow','true',true);
  update public.accommodation_properties
  set approval_status=case when p_approve then 'approved' else 'rejected' end,
      is_active=p_approve,approval_notes=p_notes,
      approved_at=case when p_approve then now() else null end,
      approved_by=case when p_approve then auth.uid() else null end
  where id=p_property_id and module='pg' returning * into v;
  if v.id is null then raise exception 'PG property not found'; end if;
  return v;
end;
$$;
revoke all on function public.decide_pg_property(uuid,boolean,text) from public,anon;
grant execute on function public.decide_pg_property(uuid,boolean,text) to authenticated;

create or replace function public.reserve_accommodation(
  p_property_id uuid,
  p_unit_id uuid,
  p_move_in date default null,
  p_check_in date default null,
  p_check_out date default null,
  p_guests integer default 1,
  p_idempotency_key uuid default null
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_user uuid:=auth.uid(); v_module text; v_inventory integer; v_rent numeric(12,2); v_deposit numeric(12,2); v_price numeric(12,2); v_id uuid; v_reserved bigint;
begin
  if v_user is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_guests<1 then raise exception 'invalid guest count'; end if;
  if p_idempotency_key is not null then
    select id into v_id from public.accommodation_reservations where user_id=v_user and idempotency_key=p_idempotency_key;
    if v_id is not null then return v_id; end if;
  end if;
  select p.module,u.inventory,u.rent_monthly,u.deposit,u.price_nightly
  into v_module,v_inventory,v_rent,v_deposit,v_price
  from public.accommodation_properties p join public.accommodation_units u on u.property_id=p.id
  where p.id=p_property_id and u.id=p_unit_id and p.is_active and u.is_active
    and u.available_from<=coalesce(p_move_in,p_check_in)
    and (p.module<>'pg' or p.approval_status='approved');
  if not found then raise exception 'unit unavailable'; end if;
  perform pg_advisory_xact_lock(hashtext(p_unit_id::text));
  if v_module='pg' then
    if p_move_in is null or p_move_in<current_date then raise exception 'invalid move-in date'; end if;
    select count(*) into v_reserved from public.accommodation_reservations where unit_id=p_unit_id and status in ('reserved','payment_pending','confirmed');
    if v_reserved>=v_inventory then raise exception 'unit unavailable'; end if;
    insert into public.accommodation_reservations(user_id,property_id,unit_id,module,move_in_date,guests,amount,monthly_rent,deposit_amount,payment_status,status,idempotency_key)
    values(v_user,p_property_id,p_unit_id,v_module,p_move_in,p_guests,coalesce(v_deposit,0),coalesce(v_rent,0),coalesce(v_deposit,0),case when coalesce(v_deposit,0)>0 then 'pending' else 'captured' end,case when coalesce(v_deposit,0)>0 then 'payment_pending' else 'confirmed' end,coalesce(p_idempotency_key,gen_random_uuid())) returning id into v_id;
    return v_id;
  end if;
  if p_check_in is null or p_check_out is null or p_check_in<current_date or p_check_out<=p_check_in then raise exception 'invalid stay dates'; end if;
  select count(*) into v_reserved from public.accommodation_reservations where unit_id=p_unit_id and status in ('reserved','confirmed') and check_in<p_check_out and check_out>p_check_in;
  if v_reserved>=v_inventory then raise exception 'unit unavailable'; end if;
  insert into public.accommodation_reservations(user_id,property_id,unit_id,module,check_in,check_out,guests,amount,payment_status,status,idempotency_key)
  values(v_user,p_property_id,p_unit_id,v_module,p_check_in,p_check_out,p_guests,coalesce(v_price,0)*(p_check_out-p_check_in),'unpaid','reserved',coalesce(p_idempotency_key,gen_random_uuid())) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.reserve_accommodation(uuid,uuid,date,date,date,integer) from public,anon;
revoke all on function public.reserve_accommodation(uuid,uuid,date,date,date,integer,uuid) from public,anon;
grant execute on function public.reserve_accommodation(uuid,uuid,date,date,date,integer,uuid) to authenticated;

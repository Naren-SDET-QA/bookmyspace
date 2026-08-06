-- PG / Co-Living V1 additive foundation.
-- Forward-only; existing migrations are untouched.

alter table public.accommodation_properties add column if not exists approval_status text not null default 'approved';
alter table public.accommodation_properties add column if not exists approval_notes text;
alter table public.accommodation_properties add column if not exists submitted_at timestamptz;
alter table public.accommodation_properties add column if not exists approved_at timestamptz;
alter table public.accommodation_properties add column if not exists approved_by uuid references auth.users(id);
alter table public.accommodation_properties drop constraint if exists accommodation_properties_approval_status_check;
alter table public.accommodation_properties add constraint accommodation_properties_approval_status_check check (approval_status in ('draft','pending','approved','rejected'));

alter table public.accommodation_reservations add column if not exists monthly_rent numeric(12,2) not null default 0;
alter table public.accommodation_reservations add column if not exists deposit_amount numeric(12,2) not null default 0;
alter table public.accommodation_reservations add column if not exists payment_status text not null default 'unpaid';
alter table public.accommodation_reservations add column if not exists payment_reference text;
alter table public.accommodation_reservations add column if not exists updated_at timestamptz not null default now();
alter table public.accommodation_reservations add column if not exists cancelled_at timestamptz;
alter table public.accommodation_reservations add column if not exists idempotency_key uuid default gen_random_uuid();
update public.accommodation_reservations set idempotency_key = coalesce(idempotency_key,id);
alter table public.accommodation_reservations alter column idempotency_key set not null;
alter table public.accommodation_reservations drop constraint if exists accommodation_reservations_status_check;
alter table public.accommodation_reservations add constraint accommodation_reservations_status_check check (status in ('reserved','payment_pending','confirmed','cancelled','completed'));
alter table public.accommodation_reservations drop constraint if exists accommodation_reservations_payment_status_check;
alter table public.accommodation_reservations add constraint accommodation_reservations_payment_status_check check (payment_status in ('unpaid','pending','captured','failed','refunded','partially_refunded'));
create unique index if not exists accommodation_reservations_user_idempotency_idx on public.accommodation_reservations(user_id,idempotency_key);

-- Public PG reads require approval; owners/admins retain private review access.
drop policy if exists accommodation_properties_public_read on public.accommodation_properties;
create policy accommodation_properties_public_read on public.accommodation_properties for select to anon,authenticated using (is_active and (module <> 'pg' or approval_status = 'approved'));
drop policy if exists accommodation_properties_owner_read on public.accommodation_properties;
create policy accommodation_properties_owner_read on public.accommodation_properties for select to authenticated using (exists (select 1 from public.organizations o where o.id=org_id and (o.owner_user_id=auth.uid() or public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'))));
drop policy if exists accommodation_units_public_read on public.accommodation_units;
create policy accommodation_units_public_read on public.accommodation_units for select to anon,authenticated using (is_active and exists (select 1 from public.accommodation_properties p where p.id=property_id and p.is_active and (p.module <> 'pg' or p.approval_status='approved')));
drop policy if exists accommodation_units_owner_read on public.accommodation_units;
create policy accommodation_units_owner_read on public.accommodation_units for select to authenticated using (exists (select 1 from public.accommodation_properties p join public.organizations o on o.id=p.org_id where p.id=property_id and (o.owner_user_id=auth.uid() or public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'))));
drop policy if exists accommodation_visits_owner_read on public.accommodation_visits;
create policy accommodation_visits_owner_read on public.accommodation_visits for select to authenticated using (exists (select 1 from public.accommodation_properties p join public.organizations o on o.id=p.org_id where p.id=property_id and (o.owner_user_id=auth.uid() or public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'))));
drop policy if exists accommodation_reservations_owner_read on public.accommodation_reservations;
create policy accommodation_reservations_owner_read on public.accommodation_reservations for select to authenticated using (exists (select 1 from public.accommodation_properties p join public.organizations o on o.id=p.org_id where p.id=property_id and (o.owner_user_id=auth.uid() or public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'))));
create or replace function public.submit_pg_property(p_property_id uuid)
returns public.accommodation_properties language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.accommodation_properties;
begin
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

create or replace function public.reserve_accommodation(p_property_id uuid,p_unit_id uuid,p_move_in date default null,p_check_in date default null,p_check_out date default null,p_guests integer default 1)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid:=auth.uid(); v_module text; v_inventory integer; v_rent numeric(12,2); v_deposit numeric(12,2); v_id uuid; v_reserved bigint;
begin
  if v_user is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_guests<1 then raise exception 'invalid guest count'; end if;
  select p.module,u.inventory,u.rent_monthly,u.deposit into v_module,v_inventory,v_rent,v_deposit
  from public.accommodation_properties p join public.accommodation_units u on u.property_id=p.id
  where p.id=p_property_id and u.id=p_unit_id and p.is_active and u.is_active
    and u.available_from<=coalesce(p_move_in,p_check_in)
    and (p.module<>'pg' or p.approval_status='approved');
  if not found then raise exception 'unit unavailable'; end if;
  perform pg_advisory_xact_lock(hashtext(p_unit_id::text));
  if v_module='pg' then
    if p_move_in is null or p_move_in<current_date then raise exception 'invalid move-in date'; end if;
    select count(*) into v_reserved from public.accommodation_reservations
      where unit_id=p_unit_id and status in ('reserved','payment_pending','confirmed');
    if v_reserved>=v_inventory then raise exception 'unit unavailable'; end if;
    insert into public.accommodation_reservations(user_id,property_id,unit_id,module,move_in_date,guests,amount,monthly_rent,deposit_amount,payment_status,status)
    values(v_user,p_property_id,p_unit_id,v_module,p_move_in,p_guests,coalesce(v_deposit,0),coalesce(v_rent,0),coalesce(v_deposit,0),case when coalesce(v_deposit,0)>0 then 'pending' else 'captured' end,case when coalesce(v_deposit,0)>0 then 'payment_pending' else 'confirmed' end)
    returning id into v_id;
    return v_id;
  end if;
  -- Preserve legacy non-PG behavior for callers still using this shared RPC.
  if p_check_in is null or p_check_out is null or p_check_in<current_date or p_check_out<=p_check_in then raise exception 'invalid stay dates'; end if;
  select count(*) into v_reserved from public.accommodation_reservations where unit_id=p_unit_id and status in ('reserved','confirmed') and check_in<p_check_out and check_out>p_check_in;
  if v_reserved>=v_inventory then raise exception 'unit unavailable'; end if;
  insert into public.accommodation_reservations(user_id,property_id,unit_id,module,check_in,check_out,guests,amount,payment_status,status)
  values(v_user,p_property_id,p_unit_id,v_module,p_check_in,p_check_out,p_guests,coalesce(v_rent,0),'unpaid','reserved') returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.reserve_accommodation(uuid,uuid,date,date,date,integer) from public,anon;
grant execute on function public.reserve_accommodation(uuid,uuid,date,date,date,integer) to authenticated;

create or replace function public.cancel_pg_reservation(p_reservation_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid; v_status text; v_module text;
begin
  select user_id,status,module into v_user,v_status,v_module from public.accommodation_reservations where id=p_reservation_id for update;
  if v_module<>'pg' or v_user<>auth.uid() then raise exception 'not permitted' using errcode='42501'; end if;
  if v_status not in ('payment_pending','confirmed','reserved') then raise exception 'reservation not cancellable'; end if;
  update public.accommodation_reservations set status='cancelled',cancelled_at=now(),updated_at=now() where id=p_reservation_id;
end;
$$;
revoke all on function public.cancel_pg_reservation(uuid) from public,anon;
grant execute on function public.cancel_pg_reservation(uuid) to authenticated;
create or replace function public.sync_pg_commerce_reference()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_org uuid; v_name text;
begin
  if new.module<>'pg' then return new; end if;
  select o.owner_user_id,o.id,p.name into v_owner,v_org,v_name from public.accommodation_properties p join public.organizations o on o.id=p.org_id where p.id=new.property_id;
  insert into public.commerce_references(module,resource_id,reservation_id,owner_user_id,org_id,customer_user_id,amount,currency,booking_status,payment_status,metadata)
  values('pg',new.property_id,new.id,v_owner,v_org,new.user_id,new.deposit_amount,'INR',new.status,new.payment_status,jsonb_build_object('property_name',v_name,'monthly_rent',new.monthly_rent,'deposit_amount',new.deposit_amount,'move_in_date',new.move_in_date))
  on conflict(module,reservation_id) do update set amount=excluded.amount,booking_status=excluded.booking_status,payment_status=excluded.payment_status,metadata=excluded.metadata,updated_at=now();
  return new;
end;
$$;
drop trigger if exists trg_sync_pg_commerce on public.accommodation_reservations;
create trigger trg_sync_pg_commerce after insert or update of status,payment_status on public.accommodation_reservations for each row execute function public.sync_pg_commerce_reference();
revoke all on function public.sync_pg_commerce_reference() from public,anon,authenticated;

create or replace function public.apply_commerce_payment(p_reference_id uuid,p_payment_ref text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.commerce_references;
begin
  select * into c from public.commerce_references where id=p_reference_id for update;
  if not found then raise exception 'commerce reference not found'; end if;
  if c.payment_status='captured' and c.booking_status='confirmed' then return; end if;
  update public.commerce_references set payment_status='captured',booking_status='confirmed',updated_at=now() where id=c.id;
  if c.module='stays' then
    update public.stay_bookings set payment_status='captured',status='confirmed',updated_at=now() where id=c.reservation_id and status='payment_pending';
  elsif c.module='pg' then
    update public.accommodation_reservations set payment_status='captured',payment_reference=p_payment_ref,status='confirmed',updated_at=now() where id=c.reservation_id and module='pg' and status='payment_pending';
  else
    update public.bookings set workflow_status='paid' where id=c.legacy_booking_id and workflow_status='payment_pending';
    perform public.confirm_booking(c.legacy_booking_id,p_payment_ref);
  end if;
end;
$$;
revoke all on function public.apply_commerce_payment(uuid,text) from public,anon,authenticated;
grant execute on function public.apply_commerce_payment(uuid,text) to service_role;

create or replace function public.apply_commerce_refund(p_reference_id uuid,p_partial boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c public.commerce_references; v_status text:=case when p_partial then 'partially_refunded' else 'refunded' end;
begin
  select * into c from public.commerce_references where id=p_reference_id for update;
  if not found then raise exception 'commerce reference not found'; end if;
  if c.refund_status in ('refunded','partially_refunded') then return; end if;
  update public.commerce_references set payment_status=v_status,refund_status=v_status,booking_status=v_status,updated_at=now() where id=c.id;
  if c.module='stays' then
    update public.stay_bookings set payment_status=v_status,status=v_status,updated_at=now() where id=c.reservation_id;
    update public.stay_booking_rooms set active=false where stay_booking_id=c.reservation_id and not p_partial;
  elsif c.module='pg' then
    update public.accommodation_reservations set payment_status=v_status,status='cancelled',cancelled_at=now(),updated_at=now() where id=c.reservation_id and module='pg';
  else
    update public.bookings set status=case when p_partial then status else 'refunded'::booking_status end,workflow_status=v_status where id=c.legacy_booking_id;
  end if;
end;
$$;
revoke all on function public.apply_commerce_refund(uuid,boolean) from public,anon,authenticated;
grant execute on function public.apply_commerce_refund(uuid,boolean) to service_role;

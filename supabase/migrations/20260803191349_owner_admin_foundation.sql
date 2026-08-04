alter table public.owner_profiles
  add column if not exists phone text,
  add column if not exists whatsapp text,
  add column if not exists photo_url text;

drop policy if exists "owner_profiles_own" on public.owner_profiles;
drop policy if exists "owner_profiles_owner_read" on public.owner_profiles;
create policy owner_profiles_select_own on public.owner_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy owner_profiles_update_own on public.owner_profiles
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "organizations_owner_write" on public.organizations;
drop policy if exists "organizations_owner_read" on public.organizations;

insert into public.user_roles(user_id, role)
select user_id, 'venue_owner'::public.user_role from public.owner_profiles
on conflict(user_id, role) do update set revoked_at = null;

create or replace function public.current_app_role()
returns text language sql security definer stable
set search_path = public, pg_temp
as $$
  select case
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='super_administrator' and revoked_at is null) then 'admin'
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='administrator' and revoked_at is null) then 'admin'
    when exists(select 1 from public.user_roles where user_id=auth.uid() and role='venue_owner' and revoked_at is null) then 'owner'
    else 'customer' end;
$$;
revoke all on function public.current_app_role() from public, anon;
grant execute on function public.current_app_role() to authenticated;

create or replace function public.save_owner_profile(
  p_name text,
  p_phone text default null,
  p_whatsapp text default null,
  p_business_name text default null,
  p_address text default null,
  p_city text default null,
  p_state text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_photo_url text default null
) returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_uid uuid:=auth.uid(); v_email text; v_org uuid;
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  select email into v_email from auth.users where id=v_uid;
  if nullif(trim(p_name),'') is null then raise exception 'name required'; end if;
  insert into public.owner_profiles(user_id,email,name,phone,whatsapp,photo_url)
  values(v_uid,v_email,trim(p_name),p_phone,p_whatsapp,p_photo_url)
  on conflict(user_id) do update set name=excluded.name,phone=excluded.phone,
    whatsapp=excluded.whatsapp,photo_url=excluded.photo_url,updated_at=now();
  insert into public.profiles(id,full_name,phone,email,avatar_url)
  values(v_uid,trim(p_name),p_phone,v_email,p_photo_url)
  on conflict(id) do update set full_name=excluded.full_name,phone=excluded.phone,
    avatar_url=excluded.avatar_url,updated_at=now();
  insert into public.user_roles(user_id,role) values(v_uid,'venue_owner')
  on conflict(user_id,role) do update set revoked_at=null;
  select id into v_org from public.organizations where owner_user_id=v_uid and deleted_at is null limit 1;
  if v_org is null then
    insert into public.organizations(owner_user_id,org_type,name,address_line1,city,state,latitude,longitude)
    values(v_uid,'venue_owner',coalesce(nullif(trim(p_business_name),''),trim(p_name)),p_address,p_city,p_state,p_latitude,p_longitude)
    returning id into v_org;
  else
    update public.organizations set
      name=coalesce(nullif(trim(p_business_name),''),name),address_line1=p_address,
      city=p_city,state=p_state,latitude=p_latitude,longitude=p_longitude,updated_at=now()
    where id=v_org;
  end if;
  update public.profiles set default_org_id=v_org where id=v_uid;
  return public.get_owner_profile();
end; $$;

create or replace function public.get_owner_profile()
returns jsonb language sql security definer stable
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'id',op.id,'user_id',op.user_id,'email',op.email,'name',op.name,
    'phone',op.phone,'whatsapp',op.whatsapp,'photo_url',op.photo_url,
    'business_name',o.name,'address',o.address_line1,'city',o.city,'state',o.state,
    'latitude',o.latitude,'longitude',o.longitude,'org_id',o.id)
  from public.owner_profiles op
  left join public.organizations o on o.owner_user_id=op.user_id and o.deleted_at is null
  where op.user_id=auth.uid() order by o.created_at limit 1;
$$;
revoke all on function public.save_owner_profile(text,text,text,text,text,text,text,double precision,double precision,text) from public, anon;
revoke all on function public.get_owner_profile() from public, anon;
grant execute on function public.save_owner_profile(text,text,text,text,text,text,text,double precision,double precision,text) to authenticated;
grant execute on function public.get_owner_profile() to authenticated;

create or replace function public.owner_decide_booking(p_booking_id uuid,p_accept boolean)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.bookings b set status=case when p_accept then 'confirmed'::public.booking_status else 'cancelled'::public.booking_status end,
    confirmed_at=case when p_accept then now() else null end,
    cancelled_at=case when p_accept then null else now() end
  where b.id=p_booking_id and b.status='pending' and exists(
    select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=b.venue_id and o.owner_user_id=auth.uid());
  if not found then raise exception 'booking not found or not permitted'; end if;
end; $$;
revoke all on function public.owner_decide_booking(uuid,boolean) from public, anon;
grant execute on function public.owner_decide_booking(uuid,boolean) to authenticated;

create or replace function public.create_offline_booking(
  p_venue_id uuid,p_slot_id uuid,p_book_date date,p_customer_name text,p_customer_phone text
) returns uuid language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_slot public.time_slots; v_id uuid; v_amount numeric; v_tax numeric;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  perform pg_advisory_xact_lock(hashtext(p_venue_id::text||p_book_date::text));
  select s.* into v_slot from public.time_slots s join public.venues v on v.id=s.venue_id
  join public.organizations o on o.id=v.org_id
  where s.id=p_slot_id and s.venue_id=p_venue_id and s.is_active and o.owner_user_id=auth.uid();
  if not found then raise exception 'slot not found or not permitted'; end if;
  select v_slot.price_amount,round(v_slot.price_amount*v.tax_rate/100,2) into v_amount,v_tax
  from public.venues v where v.id=p_venue_id;
  insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,amount,tax_amount,total_amount,metadata,confirmed_at)
  values('OFF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid(),p_venue_id,p_slot_id,p_book_date,
    v_slot.start_time,v_slot.end_time,'confirmed',v_amount,v_tax,v_amount+v_tax,
    jsonb_build_object('source','offline','customer_name',p_customer_name,'customer_phone',p_customer_phone),now())
  returning id into v_id;
  return v_id;
end; $$;
revoke all on function public.create_offline_booking(uuid,uuid,date,text,text) from public, anon;
grant execute on function public.create_offline_booking(uuid,uuid,date,text,text) to authenticated;

-- Restrict all existing privileged owner RPCs to authenticated callers.
revoke all on function public.get_owner_venues() from public, anon;
revoke all on function public.create_owner_venue(text,uuid,text,text,text,double precision,double precision,integer,numeric) from public, anon;
revoke all on function public.update_owner_venue(uuid,text,uuid,text,text,text,double precision,double precision,integer,numeric,boolean) from public, anon;
revoke all on function public.delete_owner_venue(uuid) from public, anon;
revoke all on function public.delete_owner_account(uuid) from public, anon;
grant execute on function public.get_owner_venues() to authenticated;
grant execute on function public.create_owner_venue(text,uuid,text,text,text,double precision,double precision,integer,numeric) to authenticated;
grant execute on function public.update_owner_venue(uuid,text,uuid,text,text,text,double precision,double precision,integer,numeric,boolean) to authenticated;
grant execute on function public.delete_owner_venue(uuid) to authenticated;
grant execute on function public.delete_owner_account(uuid) to authenticated;

alter function public.get_owner_venues() set search_path=public,pg_temp;
alter function public.create_owner_venue(text,uuid,text,text,text,double precision,double precision,integer,numeric) set search_path=public,pg_temp;
alter function public.update_owner_venue(uuid,text,uuid,text,text,text,double precision,double precision,integer,numeric,boolean) set search_path=public,pg_temp;
alter function public.delete_owner_venue(uuid) set search_path=public,pg_temp;

create or replace function public.delete_owner_account(p_user_id uuid)
returns void language plpgsql security definer
set search_path=public,pg_temp
as $$ begin
  if auth.uid() is null or auth.uid()<>p_user_id then raise exception 'not permitted'; end if;
  delete from public.owner_profiles where user_id=auth.uid();
end; $$;
revoke all on function public.delete_owner_account(uuid) from public,anon;
grant execute on function public.delete_owner_account(uuid) to authenticated;

grant select,insert,update,delete on public.time_slots,public.venue_blocked_dates to authenticated;

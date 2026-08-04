create extension if not exists btree_gist with schema extensions;
alter table public.accommodation_properties add column if not exists photos text[] not null default '{}',add column if not exists check_in_time time not null default '14:00',add column if not exists check_out_time time not null default '11:00',add column if not exists booking_mode text not null default 'instant' check(booking_mode in('instant','approval')),add column if not exists stay_rules jsonb not null default '{}',add column if not exists registration_form_id uuid references public.registration_form_templates(id);
alter table public.accommodation_units add column if not exists photos text[] not null default '{}',add column if not exists max_adults integer not null default 2 check(max_adults>0),add column if not exists max_children integer not null default 1 check(max_children>=0);

create table public.stay_physical_rooms(
 id uuid primary key default gen_random_uuid(),unit_id uuid not null references public.accommodation_units(id) on delete cascade,
 room_code text not null,is_active boolean not null default true,created_at timestamptz not null default now(),unique(unit_id,room_code)
);
create table public.stay_rates(
 id uuid primary key default gen_random_uuid(),unit_id uuid not null references public.accommodation_units(id) on delete cascade,
 start_date date not null,end_date date not null,nightly_rate numeric(12,2) not null check(nightly_rate>=0),taxes jsonb not null default '[]',fees jsonb not null default '[]',discount numeric(12,2) not null default 0 check(discount>=0),
 check(end_date>=start_date),unique(unit_id,start_date,end_date)
);
create table public.stay_blocks(
 id uuid primary key default gen_random_uuid(),physical_room_id uuid not null references public.stay_physical_rooms(id) on delete cascade,
 stay_dates daterange not null,reason text not null default '',created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 exclude using gist(physical_room_id with =,stay_dates with &&)
);
create table public.stay_bookings(
 id uuid primary key default gen_random_uuid(),booking_ref text not null unique default('STY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
 idempotency_key uuid not null,user_id uuid not null references auth.users(id),property_id uuid not null references public.accommodation_properties(id),
 check_in date not null,check_out date not null,adults integer not null check(adults>0),children integer not null default 0 check(children>=0),
 status text not null check(status in('requested','payment_pending','confirmed','rejected','cancelled','completed','no_show','refunded','partially_refunded')),
 currency text not null default 'INR',subtotal numeric(12,2) not null,discount numeric(12,2) not null default 0,tax_total numeric(12,2) not null default 0,fee_total numeric(12,2) not null default 0,total numeric(12,2) not null,
 payment_status text not null default 'unpaid',registration_submission_id uuid references public.registration_submissions(id),is_offline boolean not null default false,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,idempotency_key),check(check_out>check_in)
);
create table public.stay_booking_rooms(
 id uuid primary key default gen_random_uuid(),stay_booking_id uuid not null references public.stay_bookings(id) on delete cascade,
 physical_room_id uuid not null references public.stay_physical_rooms(id),unit_id uuid not null references public.accommodation_units(id),nightly_rate numeric(12,2) not null,stay_dates daterange not null,active boolean not null default true,
 exclude using gist(physical_room_id with =,stay_dates with &&) where(active)
);

insert into public.stay_physical_rooms(unit_id,room_code)
select u.id,'ROOM-'||n from public.accommodation_units u join public.accommodation_properties p on p.id=u.property_id cross join lateral generate_series(1,u.inventory)n where p.module='stay' on conflict do nothing;

alter table public.stay_physical_rooms enable row level security;alter table public.stay_rates enable row level security;alter table public.stay_blocks enable row level security;alter table public.stay_bookings enable row level security;alter table public.stay_booking_rooms enable row level security;
create policy stay_rooms_owner_read on public.stay_physical_rooms for select to authenticated using(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where u.id=unit_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_rooms_owner_write on public.stay_physical_rooms for all to authenticated using(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where u.id=unit_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))))with check(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where u.id=unit_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_rates_public_read on public.stay_rates for select to anon,authenticated using(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id where u.id=unit_id and p.is_active));
create policy stay_rates_owner_write on public.stay_rates for all to authenticated using(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where u.id=unit_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))))with check(exists(select 1 from accommodation_units u join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where u.id=unit_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_blocks_owner_read on public.stay_blocks for select to authenticated using(exists(select 1 from stay_physical_rooms r join accommodation_units u on u.id=r.unit_id join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where r.id=physical_room_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_blocks_owner_write on public.stay_blocks for all to authenticated using(exists(select 1 from stay_physical_rooms r join accommodation_units u on u.id=r.unit_id join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where r.id=physical_room_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))))with check(exists(select 1 from stay_physical_rooms r join accommodation_units u on u.id=r.unit_id join accommodation_properties p on p.id=u.property_id join organizations o on o.id=p.org_id where r.id=physical_room_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_bookings_read on public.stay_bookings for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from accommodation_properties p join organizations o on o.id=p.org_id where p.id=property_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy stay_booking_rooms_read on public.stay_booking_rooms for select to authenticated using(exists(select 1 from stay_bookings b where b.id=stay_booking_id and(b.user_id=(select auth.uid()) or exists(select 1 from accommodation_properties p join organizations o on o.id=p.org_id where p.id=b.property_id and(o.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))))));
grant select on public.stay_rates to anon,authenticated;grant select,insert,update,delete on public.stay_physical_rooms to authenticated;grant insert,update,delete on public.stay_rates,public.stay_blocks to authenticated;grant select on public.stay_blocks,public.stay_bookings,public.stay_booking_rooms to authenticated;

create or replace function public.available_stay_units(p_property_id uuid,p_check_in date,p_check_out date,p_adults integer,p_children integer)
returns table(unit_id uuid,available integer,nightly_rate numeric) language sql stable security definer set search_path=public,pg_temp as $$
 select u.id,count(r.id)::integer,coalesce((select sr.nightly_rate from stay_rates sr where sr.unit_id=u.id and sr.start_date<=p_check_in and sr.end_date>=p_check_out-1 order by sr.start_date desc limit 1),u.price_nightly)
 from accommodation_units u join accommodation_properties p on p.id=u.property_id join stay_physical_rooms r on r.unit_id=u.id and r.is_active
 where p.id=p_property_id and p.module='stay' and p.is_active and u.is_active and p_check_out>p_check_in and p_adults>0 and p_children>=0 and u.max_adults>=p_adults and u.max_children>=p_children
 and not exists(select 1 from stay_blocks x where x.physical_room_id=r.id and x.stay_dates&&daterange(p_check_in,p_check_out,'[)'))
 and not exists(select 1 from stay_booking_rooms br where br.physical_room_id=r.id and br.active and br.stay_dates&&daterange(p_check_in,p_check_out,'[)'))
 group by u.id,u.price_nightly;
$$;revoke all on function public.available_stay_units(uuid,date,date,integer,integer) from public;grant execute on function public.available_stay_units(uuid,date,date,integer,integer) to anon,authenticated;

create or replace function public.create_stay_booking(p_property_id uuid,p_check_in date,p_check_out date,p_adults integer,p_children integer,p_rooms jsonb,p_idempotency_key uuid,p_registration_submission_id uuid default null,p_offline_customer uuid default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_actor uuid:=auth.uid();v_customer uuid:=coalesce(p_offline_customer,v_actor);v_owner uuid;v_mode text;v_booking uuid;v_sub numeric:=0;v_discount numeric:=0;v_tax numeric:=0;v_fee numeric:=0;v_item jsonb;v_charge jsonb;v_unit uuid;v_qty int;v_rate numeric;v_room uuid;v_nights int:=p_check_out-p_check_in;i int;v_taxes jsonb:='[]';v_fees jsonb:='[]';v_rate_discount numeric:=0;v_base numeric;
begin
 if v_actor is null then raise exception 'authentication required' using errcode='42501';end if;if p_check_in<current_date or p_check_out<=p_check_in then raise exception 'invalid stay dates' using errcode='22023';end if;
 select o.owner_user_id,p.booking_mode into v_owner,v_mode from accommodation_properties p join organizations o on o.id=p.org_id where p.id=p_property_id and p.module='stay' and p.is_active;if not found then raise exception 'property unavailable';end if;
 if p_offline_customer is not null and v_actor<>v_owner and not public.has_role(v_actor,'administrator') then raise exception 'owner required for offline booking' using errcode='42501';end if;
 if jsonb_typeof(p_rooms)<>'array' or jsonb_array_length(p_rooms)=0 then raise exception 'select rooms' using errcode='22023';end if;
 if exists(select 1 from stay_bookings where user_id=v_customer and idempotency_key=p_idempotency_key)then select id into v_booking from stay_bookings where user_id=v_customer and idempotency_key=p_idempotency_key;return v_booking;end if;
 for v_item in select * from jsonb_array_elements(p_rooms) order by value->>'unit_id' loop
  v_unit:=(v_item->>'unit_id')::uuid;v_qty:=greatest((v_item->>'quantity')::int,1);perform pg_advisory_xact_lock(hashtext(v_unit::text));
  select nightly_rate into v_rate from available_stay_units(p_property_id,p_check_in,p_check_out,p_adults,p_children) where unit_id=v_unit and available>=v_qty;if not found then raise exception 'room no longer available' using errcode='P0001';end if;
  select taxes,fees,discount into v_taxes,v_fees,v_rate_discount from stay_rates where unit_id=v_unit and start_date<=p_check_in and end_date>=p_check_out-1 order by start_date desc limit 1;if not found then v_taxes:='[]';v_fees:='[]';v_rate_discount:=0;end if;
  v_base:=v_rate*v_nights*v_qty;v_sub:=v_sub+v_base;v_discount:=v_discount+least(v_rate_discount*v_qty,v_base);
  for v_charge in select * from jsonb_array_elements(v_taxes)loop v_tax:=v_tax+case when v_charge->>'type'='percent' then v_base*coalesce((v_charge->>'value')::numeric,0)/100 else coalesce((v_charge->>'value')::numeric,0)*v_qty end;end loop;
  for v_charge in select * from jsonb_array_elements(v_fees)loop v_fee:=v_fee+case when v_charge->>'type'='percent' then v_base*coalesce((v_charge->>'value')::numeric,0)/100 else coalesce((v_charge->>'value')::numeric,0)*v_qty end;end loop;
 end loop;
 insert into stay_bookings(user_id,property_id,idempotency_key,check_in,check_out,adults,children,status,subtotal,discount,tax_total,fee_total,total,registration_submission_id,is_offline,created_by)
 values(v_customer,p_property_id,p_idempotency_key,p_check_in,p_check_out,p_adults,p_children,case when p_offline_customer is not null then 'confirmed' when v_mode='approval' then 'requested' when v_sub=0 then 'confirmed' else 'payment_pending' end,v_sub,v_discount,v_tax,v_fee,v_sub-v_discount+v_tax+v_fee,p_registration_submission_id,p_offline_customer is not null,v_actor)returning id into v_booking;
 for v_item in select * from jsonb_array_elements(p_rooms) order by value->>'unit_id' loop
  v_unit:=(v_item->>'unit_id')::uuid;v_qty:=greatest((v_item->>'quantity')::int,1);select nightly_rate into v_rate from available_stay_units(p_property_id,p_check_in,p_check_out,p_adults,p_children)where unit_id=v_unit;
  for i in 1..v_qty loop select r.id into v_room from stay_physical_rooms r where r.unit_id=v_unit and r.is_active and not exists(select 1 from stay_blocks x where x.physical_room_id=r.id and x.stay_dates&&daterange(p_check_in,p_check_out,'[)'))and not exists(select 1 from stay_booking_rooms br where br.physical_room_id=r.id and br.stay_dates&&daterange(p_check_in,p_check_out,'[)')) order by r.room_code for update skip locked limit 1;if v_room is null then raise exception 'room no longer available';end if;insert into stay_booking_rooms(stay_booking_id,physical_room_id,unit_id,nightly_rate,stay_dates)values(v_booking,v_room,v_unit,v_rate,daterange(p_check_in,p_check_out,'[)'));end loop;
 end loop;return v_booking;
end$$;
revoke all on function public.create_stay_booking(uuid,date,date,integer,integer,jsonb,uuid,uuid,uuid) from public,anon;grant execute on function public.create_stay_booking(uuid,date,date,integer,integer,jsonb,uuid,uuid,uuid) to authenticated;

create or replace function public.update_stay_booking_status(p_booking_id uuid,p_status text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_current text;v_customer uuid;v_owner uuid;begin
 select b.status,b.user_id,o.owner_user_id into v_current,v_customer,v_owner from stay_bookings b join accommodation_properties p on p.id=b.property_id join organizations o on o.id=p.org_id where b.id=p_booking_id for update;if not found then raise exception 'booking not found';end if;
 if p_status='cancelled' and v_uid=v_customer and v_current in('requested','payment_pending','confirmed') then null;
 elsif v_uid=v_owner or public.has_role(v_uid,'administrator') then if not((v_current='requested' and p_status in('payment_pending','confirmed','rejected'))or(v_current in('payment_pending','confirmed')and p_status in('cancelled','no_show','completed','refunded','partially_refunded')))then raise exception 'invalid transition';end if;
 else raise exception 'not permitted' using errcode='42501';end if;
 update stay_bookings set status=p_status,updated_at=now() where id=p_booking_id;
 if p_status in('rejected','cancelled','refunded')then update stay_booking_rooms set active=false where stay_booking_id=p_booking_id;end if;
end$$;
revoke all on function public.update_stay_booking_status(uuid,text) from public,anon;grant execute on function public.update_stay_booking_status(uuid,text) to authenticated;

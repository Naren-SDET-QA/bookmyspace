create table public.meeting_room_profiles (
  venue_id uuid primary key references public.venues(id) on delete cascade,
  room_type text not null check(room_type in ('meeting','conference','training')),
  hourly_rate numeric(12,2) not null check(hourly_rate>=0),
  half_day_rate numeric(12,2) not null check(half_day_rate>=0),
  full_day_rate numeric(12,2) not null check(full_day_rate>=0),
  min_duration_minutes integer not null default 60 check(min_duration_minutes>=30),
  booking_increment_minutes integer not null default 30 check(booking_increment_minutes in (30,60)),
  buffer_minutes integer not null default 15 check(buffer_minutes between 0 and 240),
  booking_mode text not null default 'instant' check(booking_mode in ('instant','approval','hybrid')),
  instant_book_window_hours integer not null default 48,
  approval_timeout_minutes integer not null default 1440,
  amenities text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table public.meeting_room_breaks (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.meeting_room_profiles(venue_id) on delete cascade,
  day_of_week smallint not null check(day_of_week between 0 and 6),
  start_time time not null,
  end_time time not null,
  label text not null default 'Break',
  check(end_time>start_time)
);

create table public.meeting_booking_idempotency (
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  occurrence_date date not null,
  booking_id uuid not null references public.bookings(id) on delete cascade,
  primary key(user_id,idempotency_key,occurrence_date)
);

alter table public.meeting_room_profiles enable row level security;
alter table public.meeting_room_breaks enable row level security;
alter table public.meeting_booking_idempotency enable row level security;

create policy meeting_profiles_public_read on public.meeting_room_profiles for select using (
  exists(select 1 from public.venues v where v.id=venue_id and v.is_active and v.deleted_at is null)
);
create policy meeting_profiles_owner_write on public.meeting_room_profiles for all to authenticated
using(exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())))
with check(exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));
create policy meeting_breaks_public_read on public.meeting_room_breaks for select using(true);
create policy meeting_breaks_owner_write on public.meeting_room_breaks for all to authenticated
using(exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())))
with check(exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id where v.id=venue_id and o.owner_user_id=(select auth.uid())));
create policy meeting_idempotency_own_read on public.meeting_booking_idempotency for select to authenticated using(user_id=(select auth.uid()));

grant select on public.meeting_room_profiles,public.meeting_room_breaks to anon,authenticated;
grant insert,update,delete on public.meeting_room_profiles,public.meeting_room_breaks to authenticated;
revoke all on public.meeting_booking_idempotency from anon,authenticated;

create or replace function public.create_meeting_room(
  p_name text,p_description text,p_city text,p_state text,p_latitude double precision,p_longitude double precision,
  p_capacity integer,p_room_type text,p_hourly_rate numeric,p_half_day_rate numeric,p_full_day_rate numeric,
  p_buffer_minutes integer,p_amenities text[]
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_org uuid; v_category uuid; v_venue uuid;
begin
  select id into v_org from public.organizations where owner_user_id=auth.uid() and deleted_at is null limit 1;
  if v_org is null then raise exception 'owner organization required' using errcode='42501'; end if;
  select id into v_category from public.venue_categories where slug='meeting_room';
  insert into public.venues(org_id,category_id,name,slug,description,city,state,latitude,longitude,capacity,pricing_base_amount)
  values(v_org,v_category,trim(p_name),lower(regexp_replace(trim(p_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(gen_random_uuid()::text,1,8),
    trim(p_description),trim(p_city),trim(p_state),p_latitude,p_longitude,p_capacity,p_hourly_rate) returning id into v_venue;
  insert into public.meeting_room_profiles(venue_id,room_type,hourly_rate,half_day_rate,full_day_rate,buffer_minutes,amenities)
  values(v_venue,p_room_type,p_hourly_rate,p_half_day_rate,p_full_day_rate,p_buffer_minutes,coalesce(p_amenities,'{}'));
  insert into public.time_slots(venue_id,label,start_time,end_time,price_amount) values(v_venue,'Variable duration','00:00','23:59',p_hourly_rate);
  insert into public.venue_operating_hours(venue_id,day_of_week,opens_at,closes_at)
    select v_venue,d,'09:00','18:00' from generate_series(0,6)d;
  return v_venue;
end $$;
revoke all on function public.create_meeting_room(text,text,text,text,double precision,double precision,integer,text,numeric,numeric,numeric,integer,text[]) from public,anon;
grant execute on function public.create_meeting_room(text,text,text,text,double precision,double precision,integer,text,numeric,numeric,numeric,integer,text[]) to authenticated;

create or replace function public.meeting_room_quote(
  p_venue_id uuid,p_book_date date,p_start_time time,p_duration_minutes integer
) returns jsonb language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare r public.meeting_room_profiles; v_end time; v_day smallint; v_open time; v_close time; v_price numeric; v_available boolean:=true;
begin
  select * into r from public.meeting_room_profiles where venue_id=p_venue_id;
  if not found or p_duration_minutes<r.min_duration_minutes or mod(p_duration_minutes,r.booking_increment_minutes)<>0 then
    return jsonb_build_object('available',false,'reason','Invalid duration');
  end if;
  v_end:=p_start_time+make_interval(mins=>p_duration_minutes);
  if v_end<=p_start_time then return jsonb_build_object('available',false,'reason','Booking must end the same day'); end if;
  v_day:=((extract(dow from p_book_date)::int+6)%7)::smallint;
  select opens_at,closes_at into v_open,v_close from public.venue_operating_hours where venue_id=p_venue_id and day_of_week=v_day and not is_closed;
  if not found or p_start_time<v_open or v_end>v_close then v_available:=false; end if;
  if exists(select 1 from public.meeting_room_breaks where venue_id=p_venue_id and day_of_week=v_day and (p_start_time,v_end) overlaps(start_time,end_time)) then v_available:=false; end if;
  if exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_book_date) then v_available:=false; end if;
  if exists(select 1 from public.bookings b where b.venue_id=p_venue_id and b.book_date=p_book_date
    and b.status in ('held','pending','confirmed','completed')
    and (p_start_time,v_end) overlaps(b.start_time-make_interval(mins=>r.buffer_minutes),b.end_time+make_interval(mins=>r.buffer_minutes))) then v_available:=false; end if;
  v_price:=case when p_duration_minutes>=480 then r.full_day_rate when p_duration_minutes>=240 then r.half_day_rate
    else ceil(p_duration_minutes/30.0)*(r.hourly_rate/2) end;
  return jsonb_build_object('available',v_available,'end_time',v_end,'price',round(v_price,2),'currency','INR');
end $$;
grant execute on function public.meeting_room_quote(uuid,date,time,integer) to anon,authenticated;

create or replace function public.create_meeting_booking(
  p_venue_id uuid,p_book_date date,p_start_time time,p_duration_minutes integer,p_idempotency_key uuid,
  p_recurrence_dates date[] default '{}'
) returns uuid[] language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_date date; v_dates date[]; v_quote jsonb; v_slot uuid; v_tax numeric; v_total numeric;
  v_id uuid; v_ids uuid[]:='{}'; v_mode text; v_window integer; v_timeout integer; v_flow text;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  v_dates:=array(select distinct d from unnest(array_append(coalesce(p_recurrence_dates,'{}'),p_book_date)) d order by d);
  if cardinality(v_dates)>52 then raise exception 'maximum 52 occurrences' using errcode='22023'; end if;
  select id into v_slot from public.time_slots where venue_id=p_venue_id and label='Variable duration' and is_active limit 1;
  select booking_mode,instant_book_window_hours,approval_timeout_minutes into v_mode,v_window,v_timeout from public.meeting_room_profiles where venue_id=p_venue_id;
  if not found then raise exception 'meeting room not found' using errcode='22023'; end if;
  foreach v_date in array v_dates loop
    select booking_id into v_id from public.meeting_booking_idempotency where user_id=v_uid and idempotency_key=p_idempotency_key and occurrence_date=v_date;
    if v_id is not null then v_ids:=array_append(v_ids,v_id); continue; end if;
    perform pg_advisory_xact_lock(hashtextextended(p_venue_id::text||':'||v_date::text,0));
    v_quote:=public.meeting_room_quote(p_venue_id,v_date,p_start_time,p_duration_minutes);
    if not coalesce((v_quote->>'available')::boolean,false) then raise exception 'room unavailable on %',v_date using errcode='P0001'; end if;
    v_tax:=round((v_quote->>'price')::numeric*(select tax_rate from public.venues where id=p_venue_id)/100,2); v_total:=(v_quote->>'price')::numeric+v_tax;
    v_flow:=case when v_mode='approval' or (v_mode='hybrid' and v_date+p_start_time>localtimestamp+make_interval(hours=>v_window)) then 'requested'
      when v_total=0 then 'confirmed' else 'payment_pending' end;
    insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,workflow_status,
      amount,tax_amount,total_amount,approval_deadline,confirmed_at,metadata)
    values('MR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),v_uid,p_venue_id,v_slot,v_date,p_start_time,
      p_start_time+make_interval(mins=>p_duration_minutes),case when v_flow='confirmed' then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
      v_flow,(v_quote->>'price')::numeric,v_tax,v_total,case when v_flow='requested' then now()+make_interval(mins=>v_timeout) end,
      case when v_flow='confirmed' then now() end,jsonb_build_object('module','meeting_room','duration_minutes',p_duration_minutes,'idempotency_key',p_idempotency_key)) returning id into v_id;
    insert into public.meeting_booking_idempotency values(v_uid,p_idempotency_key,v_date,v_id);
    v_ids:=array_append(v_ids,v_id);
  end loop;
  return v_ids;
exception when exclusion_violation then raise exception 'room unavailable' using errcode='P0001';
end $$;
revoke all on function public.create_meeting_booking(uuid,date,time,integer,uuid,date[]) from public,anon;
grant execute on function public.create_meeting_booking(uuid,date,time,integer,uuid,date[]) to authenticated;

create or replace function public.create_offline_meeting_booking(
  p_venue_id uuid,p_book_date date,p_start_time time,p_duration_minutes integer,p_customer_name text,p_customer_phone text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_ids uuid[];
begin
  select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=p_venue_id;
  if v_owner is distinct from auth.uid() then raise exception 'not permitted' using errcode='42501'; end if;
  v_ids:=public.create_meeting_booking(p_venue_id,p_book_date,p_start_time,p_duration_minutes,gen_random_uuid(),'{}');
  update public.bookings set status='confirmed',workflow_status='confirmed',confirmed_at=now(),
    metadata=metadata||jsonb_build_object('source','offline','customer_name',trim(p_customer_name),'customer_phone',trim(p_customer_phone)) where id=v_ids[1];
  return v_ids[1];
end $$;
revoke all on function public.create_offline_meeting_booking(uuid,date,time,integer,text,text) from public,anon;
grant execute on function public.create_offline_meeting_booking(uuid,date,time,integer,text,text) to authenticated;

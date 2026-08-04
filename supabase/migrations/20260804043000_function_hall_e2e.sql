-- Function Hall workflow policies and server-enforced lifecycle.
create table if not exists public.hall_booking_settings (
  venue_id uuid primary key references public.venues(id) on delete cascade,
  booking_mode text not null default 'instant'
    check (booking_mode in ('instant','approval','hybrid')),
  min_notice_minutes integer not null default 0 check (min_notice_minutes >= 0),
  max_advance_days integer not null default 365 check (max_advance_days between 1 and 730),
  instant_book_window_hours integer not null default 48 check (instant_book_window_hours >= 0),
  approval_timeout_minutes integer not null default 1440 check (approval_timeout_minutes between 5 and 10080),
  checkout_hold_minutes integer not null default 10 check (checkout_hold_minutes between 2 and 30),
  updated_at timestamptz not null default now()
);

alter table public.hall_booking_settings enable row level security;
create policy hall_settings_public_read on public.hall_booking_settings for select using (true);
create policy hall_settings_owner_insert on public.hall_booking_settings for insert to authenticated
  with check (exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=venue_id and o.owner_user_id=(select auth.uid())));
create policy hall_settings_owner_update on public.hall_booking_settings for update to authenticated
  using (exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=venue_id and o.owner_user_id=(select auth.uid())))
  with check (exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=venue_id and o.owner_user_id=(select auth.uid())));
grant select on public.hall_booking_settings to anon;
grant select,insert,update on public.hall_booking_settings to authenticated;

alter table public.bookings
  add column if not exists workflow_status text not null default 'payment_pending'
    check (workflow_status in ('requested','held','approved','payment_pending','paid','confirmed','completed','rejected','cancelled','expired','blocked')),
  add column if not exists approval_deadline timestamptz,
  add column if not exists receipt_number text unique,
  add column if not exists owner_decision_at timestamptz;
create index if not exists idx_bookings_workflow on public.bookings(workflow_status,approval_deadline);

create or replace function public.acquire_booking_hold_for_current_user(
  p_venue_id uuid,p_slot_id uuid,p_book_date date,p_idempotency_key uuid,p_hold_minutes integer default 10
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_price numeric; v_start time; v_settings public.hall_booking_settings%rowtype;
  v_id uuid; v_minutes integer; v_start_at timestamp;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  select s.price_amount,s.start_time into v_price,v_start from public.time_slots s join public.venues v on v.id=s.venue_id
  where s.id=p_slot_id and s.venue_id=p_venue_id and s.is_active and v.is_active and v.deleted_at is null;
  if not found then raise exception 'invalid slot' using errcode='22023'; end if;
  select * into v_settings from public.hall_booking_settings where venue_id=p_venue_id;
  if not found then v_settings.min_notice_minutes:=0; v_settings.max_advance_days:=365; v_settings.checkout_hold_minutes:=10; end if;
  v_start_at:=p_book_date+v_start;
  if p_book_date<current_date or v_start_at<localtimestamp+make_interval(mins=>v_settings.min_notice_minutes)
    or p_book_date>current_date+v_settings.max_advance_days then
    raise exception 'outside booking window' using errcode='P0001';
  end if;
  if exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_book_date)
    or not exists(select 1 from public.venue_operating_hours where venue_id=p_venue_id
      and day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not is_closed) then
    raise exception 'slot unavailable' using errcode='P0001';
  end if;
  v_minutes:=least(greatest(coalesce(v_settings.checkout_hold_minutes,10),2),30);
  v_id:=public.acquire_booking_hold(p_venue_id,p_slot_id,p_book_date,v_uid,p_idempotency_key,v_price,v_minutes);
  return jsonb_build_object('hold_id',v_id,'expires_in_minutes',v_minutes);
end $$;
revoke all on function public.acquire_booking_hold_for_current_user(uuid,uuid,date,uuid,integer) from public,anon;
grant execute on function public.acquire_booking_hold_for_current_user(uuid,uuid,date,uuid,integer) to authenticated;

create or replace function public.create_booking_from_hold_for_current_user(p_hold_id uuid,p_booking_ref text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_id uuid; v_mode text; v_window integer; v_timeout integer;
  v_total numeric; v_start timestamp; v_flow text;
begin
  if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
  v_id:=public.create_booking_from_hold(p_hold_id,v_uid,p_booking_ref);
  select coalesce(s.booking_mode,'instant'),coalesce(s.instant_book_window_hours,48),
    coalesce(s.approval_timeout_minutes,1440),b.total_amount,b.book_date+b.start_time
    into v_mode,v_window,v_timeout,v_total,v_start from public.bookings b
    left join public.hall_booking_settings s on s.venue_id=b.venue_id where b.id=v_id;
  if v_total=0 and (v_mode='instant' or (v_mode='hybrid' and v_start<=localtimestamp+make_interval(hours=>v_window))) then
    v_flow:='confirmed';
  elsif v_mode='approval' or (v_mode='hybrid' and v_start>localtimestamp+make_interval(hours=>v_window)) then
    v_flow:='requested';
  else v_flow:='payment_pending'; end if;
  update public.bookings set workflow_status=v_flow,
    status=case when v_flow='confirmed' then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when v_flow='confirmed' then now() else null end,
    approval_deadline=case when v_flow='requested' then now()+make_interval(mins=>v_timeout) else null end
    where id=v_id;
  return v_id;
end $$;
revoke all on function public.create_booking_from_hold_for_current_user(uuid,text) from public,anon;
grant execute on function public.create_booking_from_hold_for_current_user(uuid,text) to authenticated;

create or replace function public.owner_decide_booking(p_booking_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_total numeric;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select b.total_amount into v_total from public.bookings b where b.id=p_booking_id and b.workflow_status='requested'
    and (b.approval_deadline is null or b.approval_deadline>now()) and exists(select 1 from public.venues v
      join public.organizations o on o.id=v.org_id where v.id=b.venue_id and o.owner_user_id=auth.uid()) for update;
  if not found then raise exception 'booking not found, expired or not permitted'; end if;
  update public.bookings set owner_decision_at=now(),approval_deadline=null,
    workflow_status=case when not p_accept then 'rejected' when v_total=0 then 'confirmed' else 'payment_pending' end,
    status=case when not p_accept then 'cancelled'::public.booking_status when v_total=0 then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when p_accept and v_total=0 then now() else null end,
    cancelled_at=case when not p_accept then now() else null end where id=p_booking_id;
end $$;

create or replace function public.confirm_booking(p_booking_id uuid,p_payment_ref text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.bookings set status='confirmed',workflow_status='confirmed',confirmed_at=coalesce(confirmed_at,now()),
    receipt_number=coalesce(receipt_number,'BMS-R-'||upper(substr(replace(id::text,'-',''),1,12))),
    metadata=coalesce(metadata,'{}')||jsonb_build_object('payment_ref',p_payment_ref)
  where id=p_booking_id and status='pending' and workflow_status in ('payment_pending','paid');
end $$;
revoke all on function public.confirm_booking(uuid,text) from public,anon,authenticated;
grant execute on function public.confirm_booking(uuid,text) to service_role;

create or replace function public.expire_hall_workflows() returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  perform public.expire_stale_holds();
  update public.bookings set workflow_status='expired',status='cancelled',cancelled_at=now()
    where workflow_status='requested' and approval_deadline<now();
  get diagnostics n=row_count; return n;
end $$;
revoke all on function public.expire_hall_workflows() from public,anon,authenticated;
grant execute on function public.expire_hall_workflows() to service_role;

create or replace function public.notify_hall_booking_change() returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_owner uuid;
begin
  if tg_op='INSERT' or old.workflow_status is distinct from new.workflow_status then
    insert into public.notifications(user_id,type,title,body,data) values
      (new.user_id,'booking_'||new.workflow_status,'Booking '||replace(initcap(new.workflow_status),'_',' '),
       new.booking_ref,jsonb_build_object('booking_id',new.id,'booking_ref',new.booking_ref));
    select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=new.venue_id;
    if v_owner is not null and v_owner<>new.user_id then
      insert into public.notifications(user_id,type,title,body,data) values
        (v_owner,'owner_booking_'||new.workflow_status,'Booking '||replace(initcap(new.workflow_status),'_',' '),
         new.booking_ref,jsonb_build_object('booking_id',new.id,'booking_ref',new.booking_ref));
    end if;
  end if;
  if new.workflow_status='confirmed' and new.receipt_number is null then
    new.receipt_number:='BMS-R-'||upper(substr(replace(new.id::text,'-',''),1,12));
  end if;
  return new;
end $$;
drop trigger if exists trg_hall_booking_notifications on public.bookings;
create trigger trg_hall_booking_notifications before insert or update of workflow_status on public.bookings
for each row execute function public.notify_hall_booking_change();

create or replace function public.create_offline_booking(
  p_venue_id uuid,p_slot_id uuid,p_book_date date,p_customer_name text,p_customer_phone text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_slot public.time_slots; v_id uuid; v_tax numeric;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_venue_id::text||':'||p_book_date::text,0));
  select s.* into v_slot from public.time_slots s join public.venues v on v.id=s.venue_id
    join public.organizations o on o.id=v.org_id where s.id=p_slot_id and s.venue_id=p_venue_id
    and s.is_active and o.owner_user_id=auth.uid();
  if not found then raise exception 'slot not found or not permitted'; end if;
  select round(v_slot.price_amount*v.tax_rate/100,2) into v_tax from public.venues v where v.id=p_venue_id;
  insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,
    workflow_status,amount,tax_amount,total_amount,metadata,confirmed_at)
  values('OFF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid(),p_venue_id,p_slot_id,
    p_book_date,v_slot.start_time,v_slot.end_time,'confirmed','confirmed',v_slot.price_amount,v_tax,
    v_slot.price_amount+v_tax,jsonb_build_object('source','offline','customer_name',trim(p_customer_name),
    'customer_phone',trim(p_customer_phone)),now()) returning id into v_id;
  return v_id;
exception when exclusion_violation then raise exception 'slot unavailable' using errcode='P0001';
end $$;
revoke all on function public.create_offline_booking(uuid,uuid,date,text,text) from public,anon;
grant execute on function public.create_offline_booking(uuid,uuid,date,text,text) to authenticated;

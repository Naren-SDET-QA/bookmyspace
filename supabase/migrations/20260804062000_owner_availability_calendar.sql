-- Per-date slot blocks and owner calendar operations; existing booking engine remains authoritative.
create table if not exists public.venue_slot_blocks (
  venue_id uuid not null references public.venues(id) on delete cascade,
  slot_id uuid not null references public.time_slots(id) on delete cascade,
  blocked_date date not null,
  reason text,
  created_at timestamptz not null default now(),
  primary key(slot_id,blocked_date)
);
alter table public.venue_slot_blocks enable row level security;
create policy venue_slot_blocks_owner_all on public.venue_slot_blocks for all to authenticated
  using (exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=venue_id and o.owner_user_id=(select auth.uid())))
  with check (exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=venue_id and o.owner_user_id=(select auth.uid())));
grant select,insert,update,delete on public.venue_slot_blocks to authenticated;

create or replace function public.available_time_slots(p_venue_id uuid,p_book_date date)
returns table(slot_id uuid,label text,start_time time,end_time time,price_amount numeric,is_available boolean,reason text)
language sql security definer set search_path=public,pg_temp as $$
  select s.id,s.label,s.start_time,s.end_time,s.price_amount,
    s.is_active and not exists(select 1 from public.venue_blocked_dates d where d.venue_id=s.venue_id and d.blocked_date=p_book_date)
    and not exists(select 1 from public.venue_slot_blocks x where x.slot_id=s.id and x.blocked_date=p_book_date)
    and exists(select 1 from public.venue_operating_hours h where h.venue_id=s.venue_id
      and h.day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not h.is_closed)
    and not exists(select 1 from public.booking_holds b join public.time_slots hs on hs.id=b.slot_id
      where b.venue_id=s.venue_id and b.book_date=p_book_date and b.status='active' and b.expires_at>now()
      and hs.start_time<s.end_time and hs.end_time>s.start_time)
    and not exists(select 1 from public.bookings b where b.venue_id=s.venue_id and b.book_date=p_book_date
      and b.status in ('held','pending','confirmed','completed') and b.start_time<s.end_time and b.end_time>s.start_time),
    case when not s.is_active then 'inactive'
      when exists(select 1 from public.venue_blocked_dates d where d.venue_id=s.venue_id and d.blocked_date=p_book_date) then 'blocked'
      when exists(select 1 from public.venue_slot_blocks x where x.slot_id=s.id and x.blocked_date=p_book_date) then 'blocked'
      when not exists(select 1 from public.venue_operating_hours h where h.venue_id=s.venue_id
        and h.day_of_week=((extract(dow from p_book_date)::int+6)%7)::smallint and not h.is_closed) then 'closed'
      when exists(select 1 from public.booking_holds b join public.time_slots hs on hs.id=b.slot_id
        where b.venue_id=s.venue_id and b.book_date=p_book_date and b.status='active' and b.expires_at>now()
        and hs.start_time<s.end_time and hs.end_time>s.start_time) then 'held'
      when exists(select 1 from public.bookings b where b.venue_id=s.venue_id and b.book_date=p_book_date
        and b.status in ('held','pending','confirmed','completed') and b.start_time<s.end_time and b.end_time>s.start_time) then 'booked'
      else 'available' end
  from public.time_slots s where s.venue_id=p_venue_id order by s.start_time;
$$;

create or replace function public.owner_day_slots(p_venue_id uuid,p_book_date date)
returns table(slot_id uuid,label text,start_time time,end_time time,price_amount numeric,is_active boolean,status text,
  booking_id uuid,booking_ref text,customer_name text,customer_phone text,workflow_status text)
language sql security definer set search_path=public,pg_temp as $$
  with allowed as (select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()), availability as (
    select * from public.available_time_slots(p_venue_id,p_book_date)
  )
  select s.id,s.label,s.start_time,s.end_time,s.price_amount,s.is_active,a.reason,
    b.id,b.booking_ref,coalesce(b.metadata->>'customer_name',p.full_name,p.email),
    coalesce(b.metadata->>'customer_phone',p.phone),b.workflow_status
  from public.time_slots s join allowed on true join availability a on a.slot_id=s.id
  left join lateral (select x.* from public.bookings x where x.venue_id=p_venue_id and x.book_date=p_book_date
    and x.status in ('held','pending','confirmed','completed') and x.start_time<s.end_time and x.end_time>s.start_time
    order by x.created_at desc limit 1) b on true left join public.profiles p on p.id=b.user_id
  where s.venue_id=p_venue_id order by s.start_time;
$$;
revoke all on function public.owner_day_slots(uuid,date) from public,anon;
grant execute on function public.owner_day_slots(uuid,date) to authenticated;

create or replace function public.owner_set_date_block(p_venue_id uuid,p_date date,p_blocked boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  if p_blocked then insert into public.venue_blocked_dates(venue_id,blocked_date,reason)
    values(p_venue_id,p_date,'Owner blocked') on conflict(venue_id,blocked_date) do update set reason=excluded.reason;
  else delete from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_date; end if;
end $$;

create or replace function public.owner_set_slot_block(p_venue_id uuid,p_slot_id uuid,p_date date,p_blocked boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not exists(select 1 from public.time_slots s join public.venues v on v.id=s.venue_id
    join public.organizations o on o.id=v.org_id where s.id=p_slot_id and s.venue_id=p_venue_id
    and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  if p_blocked then insert into public.venue_slot_blocks(venue_id,slot_id,blocked_date,reason)
    values(p_venue_id,p_slot_id,p_date,'Owner blocked') on conflict(slot_id,blocked_date) do nothing;
  else delete from public.venue_slot_blocks where slot_id=p_slot_id and blocked_date=p_date; end if;
end $$;

create or replace function public.owner_copy_day_availability(p_venue_id uuid,p_source date,p_targets date[])
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare d date;n integer:=0;source_blocked boolean;
begin
  if not exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
    where v.id=p_venue_id and o.owner_user_id=auth.uid()) then raise exception 'not permitted'; end if;
  source_blocked:=exists(select 1 from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=p_source);
  foreach d in array p_targets loop
    delete from public.venue_blocked_dates where venue_id=p_venue_id and blocked_date=d;
    delete from public.venue_slot_blocks where venue_id=p_venue_id and blocked_date=d;
    if source_blocked then insert into public.venue_blocked_dates(venue_id,blocked_date,reason) values(p_venue_id,d,'Copied availability'); end if;
    insert into public.venue_slot_blocks(venue_id,slot_id,blocked_date,reason)
      select venue_id,slot_id,d,'Copied availability' from public.venue_slot_blocks
      where venue_id=p_venue_id and blocked_date=p_source;
    n:=n+1;
  end loop; return n;
end $$;
revoke all on function public.owner_set_date_block(uuid,date,boolean) from public,anon;
revoke all on function public.owner_set_slot_block(uuid,uuid,date,boolean) from public,anon;
revoke all on function public.owner_copy_day_availability(uuid,date,date[]) from public,anon;
grant execute on function public.owner_set_date_block(uuid,date,boolean) to authenticated;
grant execute on function public.owner_set_slot_block(uuid,uuid,date,boolean) to authenticated;
grant execute on function public.owner_copy_day_availability(uuid,date,date[]) to authenticated;

create or replace function public.reject_blocked_hall_hold() returns trigger language plpgsql
set search_path=public,pg_temp as $$
begin
  if exists(select 1 from public.venue_blocked_dates where venue_id=new.venue_id and blocked_date=new.book_date)
    or exists(select 1 from public.venue_slot_blocks where slot_id=new.slot_id and blocked_date=new.book_date) then
    raise exception 'slot unavailable' using errcode='P0001';
  end if;
  return new;
end $$;
drop trigger if exists trg_reject_blocked_hall_hold on public.booking_holds;
create trigger trg_reject_blocked_hall_hold before insert on public.booking_holds
for each row execute function public.reject_blocked_hall_hold();

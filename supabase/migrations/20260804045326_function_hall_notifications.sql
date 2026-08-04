-- Function Hall lifecycle notifications. In-app delivery is immediate;
-- external channels use an idempotent retryable outbox.

alter table public.notifications add column if not exists dedupe_key text;
create unique index if not exists uq_notifications_dedupe
  on public.notifications(user_id, dedupe_key) where dedupe_key is not null;

do $$ begin
  if to_regclass('public.notifications_archive') is not null then
    alter table public.notifications_archive add column if not exists dedupe_key text;
  end if;
end $$;

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  booking_updates boolean not null default true,
  payment_updates boolean not null default true,
  reminders boolean not null default true,
  in_app boolean not null default true,
  push boolean not null default false,
  email boolean not null default false,
  sms boolean not null default false,
  whatsapp boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel text not null check (channel in ('push','email','sms','whatsapp')),
  status text not null default 'pending' check (status in ('pending','processing','delivered','failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(notification_id, channel)
);
create index if not exists idx_notification_delivery_retry
  on public.notification_deliveries(status, next_attempt_at)
  where status in ('pending','failed');

alter table public.notification_preferences enable row level security;
alter table public.notification_deliveries enable row level security;

drop policy if exists notification_preferences_own on public.notification_preferences;
create policy notification_preferences_own on public.notification_preferences
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists notifications_own on public.notifications;
drop policy if exists notifications_select_own on public.notifications;
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_select_own on public.notifications
  for select to authenticated using (
    (select auth.uid()) = user_id and coalesce((data->>'in_app')::boolean,true)
  );
create policy notifications_update_own on public.notifications
  for update to authenticated using (
    (select auth.uid()) = user_id and coalesce((data->>'in_app')::boolean,true)
  ) with check (
    (select auth.uid()) = user_id and coalesce((data->>'in_app')::boolean,true)
  );

grant select,insert,update on public.notification_preferences to authenticated;
revoke update on public.notifications from authenticated;
grant select,update(read,read_at) on public.notifications to authenticated;
revoke all on public.notification_deliveries from anon,authenticated;

create or replace function public.enqueue_booking_notification(
  p_user_id uuid, p_booking_id uuid, p_type text, p_title text, p_body text,
  p_category text, p_dedupe_key text, p_target_route text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_notification_id uuid; v_preferences public.notification_preferences;
begin
  if p_user_id is null then return null; end if;
  select * into v_preferences from public.notification_preferences where user_id=p_user_id;
  if (p_category='booking' and coalesce(v_preferences.booking_updates,true)=false)
    or (p_category='payment' and coalesce(v_preferences.payment_updates,true)=false)
    or (p_category='reminder' and coalesce(v_preferences.reminders,true)=false) then return null;
  end if;

  if coalesce(v_preferences.in_app,true) then
    insert into public.notifications(user_id,type,title,body,data,dedupe_key)
    values(p_user_id,p_type,p_title,p_body,
      jsonb_build_object('booking_id',p_booking_id,'target_route',p_target_route,'in_app',true),p_dedupe_key)
    on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing
    returning id into v_notification_id;
  end if;

  -- A notification row is the canonical payload for every future channel.
  if v_notification_id is null and
    (coalesce(v_preferences.push,false) or coalesce(v_preferences.email,false)
      or coalesce(v_preferences.sms,false) or coalesce(v_preferences.whatsapp,false)) then
    insert into public.notifications(user_id,type,title,body,data,dedupe_key)
    values(p_user_id,p_type,p_title,p_body,
      jsonb_build_object('booking_id',p_booking_id,'target_route',p_target_route,'in_app',false),p_dedupe_key)
    on conflict (user_id,dedupe_key) where dedupe_key is not null do nothing
    returning id into v_notification_id;
    if v_notification_id is null then
      select id into v_notification_id from public.notifications
      where user_id=p_user_id and dedupe_key=p_dedupe_key;
    end if;
  end if;

  if v_notification_id is not null then
    if coalesce(v_preferences.push,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'push') on conflict do nothing; end if;
    if coalesce(v_preferences.email,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'email') on conflict do nothing; end if;
    if coalesce(v_preferences.sms,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'sms') on conflict do nothing; end if;
    if coalesce(v_preferences.whatsapp,false) then insert into public.notification_deliveries(notification_id,channel) values(v_notification_id,'whatsapp') on conflict do nothing; end if;
  end if;
  return v_notification_id;
end $$;
revoke all on function public.enqueue_booking_notification(uuid,uuid,text,text,text,text,text,text) from public,anon,authenticated;

create or replace function public.notify_hall_booking_change() returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_owner uuid; v_customer_route text; v_owner_route text;
begin
  select o.owner_user_id into v_owner from public.venues v
    join public.organizations o on o.id=v.org_id where v.id=new.venue_id;
  v_customer_route := '/bookings?bookingId='||new.id;
  v_owner_route := '/owner/bookings?bookingId='||new.id;

  if tg_op='UPDATE' and new.status='cancelled'
    and old.status is distinct from new.status
    and new.workflow_status is not distinct from old.workflow_status then
    new.workflow_status := 'cancelled';
  end if;

  if tg_op='INSERT' then
    if new.workflow_status='requested' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'request_submitted','Request submitted',new.booking_ref,'booking',new.id||':customer:requested',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_new_request','New booking request',new.booking_ref,'booking',new.id||':owner:requested',v_owner_route);
    elsif new.workflow_status='payment_pending' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'payment_required','Payment required','Pay now to confirm '||new.booking_ref||'.','payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.workflow_status='confirmed' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    end if;
  elsif tg_op='UPDATE' and old.workflow_status is distinct from new.workflow_status then
    if new.workflow_status='payment_pending' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_approved','Booking approved','Your request '||new.booking_ref||' was approved.','booking',new.id||':customer:approved',v_customer_route);
      perform public.enqueue_booking_notification(new.user_id,new.id,'payment_required','Payment required','Pay now to confirm '||new.booking_ref||'.','payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.workflow_status='rejected' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_rejected','Booking rejected',new.booking_ref,'booking',new.id||':customer:rejected',v_customer_route);
    elsif new.workflow_status='confirmed' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_confirmed','Booking confirmed',new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    elsif new.workflow_status='cancelled' then
      perform public.enqueue_booking_notification(new.user_id,new.id,'booking_cancelled','Booking cancelled',new.booking_ref,'booking',new.id||':customer:cancelled',v_customer_route);
      perform public.enqueue_booking_notification(v_owner,new.id,'owner_booking_cancelled','Booking cancelled',new.booking_ref,'booking',new.id||':owner:cancelled',v_owner_route);
    end if;
  end if;
  if new.workflow_status='confirmed' and new.receipt_number is null then
    new.receipt_number:='BMS-R-'||upper(substr(replace(new.id::text,'-',''),1,12));
  end if;
  return new;
end $$;

drop trigger if exists trg_hall_booking_notifications on public.bookings;
create trigger trg_hall_booking_notifications before insert or update of workflow_status,status on public.bookings
for each row execute function public.notify_hall_booking_change();
revoke all on function public.notify_hall_booking_change() from public,anon,authenticated;

create or replace function public.notify_hall_payment_change() returns trigger language plpgsql security definer
set search_path=public,pg_temp as $$
declare v_booking public.bookings; v_owner uuid; v_customer_route text; v_owner_route text;
begin
  if tg_op='UPDATE' and old.status is not distinct from new.status then return new; end if;
  if new.status::text not in ('captured','failed') then return new; end if;
  select * into v_booking from public.bookings where id=new.booking_id;
  select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=v_booking.venue_id;
  v_customer_route := '/bookings?bookingId='||v_booking.id;
  v_owner_route := '/owner/payments?bookingId='||v_booking.id;
  if new.status::text='captured' then
    perform public.enqueue_booking_notification(v_booking.user_id,v_booking.id,'payment_success','Payment successful',v_booking.booking_ref,'payment',new.id||':customer:captured',v_customer_route);
    perform public.enqueue_booking_notification(v_owner,v_booking.id,'owner_payment_received','Payment received',v_booking.booking_ref,'payment',new.id||':owner:captured',v_owner_route);
  else
    perform public.enqueue_booking_notification(v_booking.user_id,v_booking.id,'payment_failed','Payment failed','Payment for '||v_booking.booking_ref||' failed. You can retry safely.','payment',new.id||':customer:failed',v_customer_route);
    perform public.enqueue_booking_notification(v_owner,v_booking.id,'owner_payment_failed','Payment failed',v_booking.booking_ref,'payment',new.id||':owner:failed',v_owner_route);
  end if;
  return new;
end $$;
drop trigger if exists trg_hall_payment_notifications on public.payments;
create trigger trg_hall_payment_notifications after insert or update of status on public.payments
for each row execute function public.notify_hall_payment_change();
revoke all on function public.notify_hall_payment_change() from public,anon,authenticated;

create or replace function public.enqueue_upcoming_booking_reminders() returns integer language plpgsql security definer
set search_path=public,pg_temp as $$
declare r record; v_owner uuid; n integer:=0;
begin
  for r in select b.* from public.bookings b where b.workflow_status='confirmed'
    and (b.book_date+b.start_time) > now()
    and (b.book_date+b.start_time) <= now()+interval '24 hours'
  loop
    select o.owner_user_id into v_owner from public.venues v join public.organizations o on o.id=v.org_id where v.id=r.venue_id;
    perform public.enqueue_booking_notification(r.user_id,r.id,'booking_reminder','Booking tomorrow',r.booking_ref,'reminder',r.id||':customer:reminder:'||r.book_date,'/bookings?bookingId='||r.id);
    perform public.enqueue_booking_notification(v_owner,r.id,'owner_booking_reminder','Upcoming booking',r.booking_ref,'reminder',r.id||':owner:reminder:'||r.book_date,'/owner/bookings?bookingId='||r.id);
    n:=n+1;
  end loop;
  return n;
end $$;
revoke all on function public.enqueue_upcoming_booking_reminders() from public,anon,authenticated;
grant execute on function public.enqueue_upcoming_booking_reminders() to service_role;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron')
    and not exists(select 1 from cron.job where jobname='hall-booking-reminders') then
    perform cron.schedule('hall-booking-reminders','0 * * * *','select public.enqueue_upcoming_booking_reminders();');
  end if;
end $$;

create or replace function public.claim_notification_deliveries(p_limit integer default 25)
returns setof public.notification_deliveries language plpgsql security definer set search_path=public,pg_temp as $$
begin
  return query with claimed as (
    select id from public.notification_deliveries
    where status in ('pending','failed') and next_attempt_at<=now() and attempts<8
    order by next_attempt_at for update skip locked limit greatest(1,least(p_limit,100))
  ) update public.notification_deliveries d set status='processing',attempts=attempts+1,updated_at=now()
    from claimed where d.id=claimed.id returning d.*;
end $$;
revoke all on function public.claim_notification_deliveries(integer) from public,anon,authenticated;
grant execute on function public.claim_notification_deliveries(integer) to service_role;

create or replace function public.complete_notification_delivery(p_delivery_id uuid,p_success boolean,p_error text default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  update public.notification_deliveries set
    status=case when p_success then 'delivered' else 'failed' end,
    delivered_at=case when p_success then now() else null end,
    last_error=case when p_success then null else left(coalesce(p_error,'delivery failed'),500) end,
    next_attempt_at=case when p_success then next_attempt_at else now()+make_interval(secs=>least(3600,power(2,attempts)::integer*30)) end,
    updated_at=now() where id=p_delivery_id and status='processing';
end $$;
revoke all on function public.complete_notification_delivery(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.complete_notification_delivery(uuid,boolean,text) to service_role;

-- Hotel/Stay booking lifecycle notifications.
-- Reuses the shared enqueue_booking_notification() outbox (FH migration
-- 20260804045326); adds stay-specific trigger wiring on stay_bookings and
-- payments (stays module). In-app is immediate; push/email/sms/whatsapp
-- deliveries are claimed by service_role workers.

create or replace function public.notify_stay_booking_change()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid; v_customer_route text; v_owner_route text;
begin
  select o.owner_user_id into v_owner
    from public.accommodation_properties p
    join public.organizations o on o.id=p.org_id
    where p.id=new.property_id;
  v_customer_route := '/stays/bookings/mine?bookingId='||new.id;
  v_owner_route := '/owner/stays?bookingId='||new.id;

  if tg_op='INSERT' then
    if new.status='requested' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'request_submitted','Stay request submitted',
        new.booking_ref,'booking',new.id||':customer:requested',v_customer_route);
      perform public.enqueue_booking_notification(
        v_owner,new.id,'owner_new_request','New stay request',
        new.booking_ref||' • '||new.check_in||' → '||new.check_out,
        'booking',new.id||':owner:requested',v_owner_route);
    elsif new.status='payment_pending' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'payment_required','Payment required',
        'Pay now to confirm '||new.booking_ref||'.',
        'payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.status='confirmed' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_confirmed','Stay confirmed',
        new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(
        v_owner,new.id,'owner_booking_confirmed','Stay confirmed',
        new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    end if;
  elsif tg_op='UPDATE' and old.status is distinct from new.status then
    if new.status='payment_pending' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_approved','Stay request approved',
        'Your request '||new.booking_ref||' was approved.',
        'booking',new.id||':customer:approved',v_customer_route);
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'payment_required','Payment required',
        'Pay now to confirm '||new.booking_ref||'.',
        'payment',new.id||':customer:payment_required',v_customer_route);
    elsif new.status='rejected' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_rejected','Stay request rejected',
        new.booking_ref,'booking',new.id||':customer:rejected',v_customer_route);
    elsif new.status='confirmed' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_confirmed','Stay confirmed',
        new.booking_ref,'booking',new.id||':customer:confirmed',v_customer_route);
      perform public.enqueue_booking_notification(
        v_owner,new.id,'owner_booking_confirmed','Stay confirmed',
        new.booking_ref,'booking',new.id||':owner:confirmed',v_owner_route);
    elsif new.status='cancelled' then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_cancelled','Stay cancelled',
        new.booking_ref,'booking',new.id||':customer:cancelled',v_customer_route);
      perform public.enqueue_booking_notification(
        v_owner,new.id,'owner_booking_cancelled','Stay cancelled',
        new.booking_ref,'booking',new.id||':owner:cancelled',v_owner_route);
    elsif new.status in ('refunded','partially_refunded') then
      perform public.enqueue_booking_notification(
        new.user_id,new.id,'booking_refunded','Stay refunded',
        new.booking_ref,'payment',new.id||':customer:refunded',v_customer_route);
      perform public.enqueue_booking_notification(
        v_owner,new.id,'owner_booking_refunded','Stay refunded',
        new.booking_ref,'payment',new.id||':owner:refunded',v_owner_route);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_stay_booking_notifications on public.stay_bookings;
create trigger trg_stay_booking_notifications
  before insert or update of status,payment_status on public.stay_bookings
  for each row execute function public.notify_stay_booking_change();
revoke all on function public.notify_stay_booking_change() from public,anon,authenticated;

create or replace function public.notify_stay_payment_change()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ref public.commerce_references; v_owner uuid; v_customer_route text; v_owner_route text;
begin
  if tg_op='UPDATE' and old.status is not distinct from new.status then return new; end if;
  if new.status::text not in ('captured','failed') then return new; end if;
  select * into v_ref from public.commerce_references where id=new.commerce_reference_id;
  if v_ref.id is null or v_ref.module<>'stays' then return new; end if;
  v_customer_route := '/stays/bookings/mine?bookingId='||v_ref.reservation_id;
  v_owner_route := '/owner/stays?bookingId='||v_ref.reservation_id;
  if new.status::text='captured' then
    perform public.enqueue_booking_notification(
      v_ref.customer_user_id,v_ref.reservation_id,'payment_success','Payment successful',
      (v_ref.metadata->>'booking_ref')::text,'payment',new.id||':customer:captured',v_customer_route);
    perform public.enqueue_booking_notification(
      v_ref.owner_user_id,v_ref.reservation_id,'owner_payment_received','Payment received',
      (v_ref.metadata->>'booking_ref')::text,'payment',new.id||':owner:captured',v_owner_route);
  else
    perform public.enqueue_booking_notification(
      v_ref.customer_user_id,v_ref.reservation_id,'payment_failed','Payment failed',
      'Payment for '||(v_ref.metadata->>'booking_ref')::text||' failed. You can retry safely.',
      'payment',new.id||':customer:failed',v_customer_route);
  end if;
  return new;
end $$;

drop trigger if exists trg_stay_payment_notifications on public.payments;
create trigger trg_stay_payment_notifications
  after insert or update of status on public.payments
  for each row execute function public.notify_stay_payment_change();
revoke all on function public.notify_stay_payment_change() from public,anon,authenticated;

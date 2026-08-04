alter table public.bookings add column if not exists rejection_reason text;

create or replace function public.owner_booking_requests()
returns table(
  id uuid,booking_ref text,venue_id uuid,hall_name text,book_date date,start_time time,end_time time,
  amount numeric,total_amount numeric,workflow_status text,approval_deadline timestamptz,owner_decision_at timestamptz,
  rejection_reason text,customer_name text,customer_phone text,created_at timestamptz
) language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  update public.bookings b set workflow_status='expired',status='cancelled',cancelled_at=now()
    where b.workflow_status='requested' and b.approval_deadline<=now()
    and exists(select 1 from public.venues v join public.organizations o on o.id=v.org_id
      where v.id=b.venue_id and o.owner_user_id=auth.uid());
  return query select b.id,b.booking_ref,b.venue_id,v.name,b.book_date,b.start_time,b.end_time,b.amount,b.total_amount,
    b.workflow_status,b.approval_deadline,b.owner_decision_at,b.rejection_reason,
    coalesce(b.metadata->>'customer_name',p.full_name,p.email,'Customer'),
    coalesce(b.metadata->>'customer_phone',p.phone,''),b.created_at
  from public.bookings b join public.venues v on v.id=b.venue_id join public.organizations o on o.id=v.org_id
  left join public.profiles p on p.id=b.user_id where o.owner_user_id=auth.uid()
    and b.workflow_status in ('requested','expired','approved','payment_pending','paid','confirmed','rejected')
  order by case when b.workflow_status='requested' then 0 else 1 end,b.created_at desc;
end $$;
revoke all on function public.owner_booking_requests() from public,anon;
grant execute on function public.owner_booking_requests() to authenticated;

create or replace function public.owner_decide_booking(p_booking_id uuid,p_accept boolean,p_reason text default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_total numeric;v_deadline timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  select b.total_amount,b.approval_deadline into v_total,v_deadline from public.bookings b
    where b.id=p_booking_id and b.workflow_status='requested' and exists(select 1 from public.venues v
      join public.organizations o on o.id=v.org_id where v.id=b.venue_id and o.owner_user_id=auth.uid()) for update;
  if not found then raise exception 'request already handled or not permitted' using errcode='P0001'; end if;
  if v_deadline is not null and v_deadline<=now() then
    update public.bookings set workflow_status='expired',status='cancelled',cancelled_at=now() where id=p_booking_id;
    raise exception 'approval request expired' using errcode='P0001';
  end if;
  if not p_accept and nullif(trim(coalesce(p_reason,'')),'') is null then
    raise exception 'rejection reason required' using errcode='22023';
  end if;
  update public.bookings set owner_decision_at=now(),approval_deadline=null,
    rejection_reason=case when p_accept then null else trim(p_reason) end,
    workflow_status=case when not p_accept then 'rejected' when v_total=0 then 'confirmed' else 'payment_pending' end,
    status=case when not p_accept then 'cancelled'::public.booking_status when v_total=0 then 'confirmed'::public.booking_status else 'pending'::public.booking_status end,
    confirmed_at=case when p_accept and v_total=0 then now() else null end,
    cancelled_at=case when not p_accept then now() else null end where id=p_booking_id;
end $$;
revoke all on function public.owner_decide_booking(uuid,boolean,text) from public,anon;
grant execute on function public.owner_decide_booking(uuid,boolean,text) to authenticated;

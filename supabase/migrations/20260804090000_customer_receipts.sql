create or replace function public.customer_booking_receipt(p_booking_id uuid)
returns jsonb language sql security definer stable set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'booking_id',b.id,'booking_ref',b.booking_ref,'receipt_number',b.receipt_number,
    'hall_name',v.name,'customer_name',coalesce(p.full_name,p.email,'Customer'),
    'customer_phone',coalesce(p.phone,''),'book_date',b.book_date,'start_time',b.start_time,
    'end_time',b.end_time,'amount',b.amount,'tax_amount',b.tax_amount,'total_amount',b.total_amount,
    'currency',b.currency,'booking_status',b.workflow_status,'payment_status',coalesce(pay.status::text,
      case when b.total_amount=0 and b.workflow_status='confirmed' then 'free' else 'pending' end),
    'payment_ref',coalesce(pay.provider_payment_id,b.metadata->>'payment_ref',''),
    'paid_at',pay.updated_at,'confirmed_at',b.confirmed_at
  ) from public.bookings b join public.venues v on v.id=b.venue_id
    left join public.profiles p on p.id=b.user_id
    left join lateral (select x.* from public.payments x where x.booking_id=b.id
      order by x.created_at desc limit 1) pay on true
  where b.id=p_booking_id and b.user_id=auth.uid();
$$;
revoke all on function public.customer_booking_receipt(uuid) from public,anon;
grant execute on function public.customer_booking_receipt(uuid) to authenticated;

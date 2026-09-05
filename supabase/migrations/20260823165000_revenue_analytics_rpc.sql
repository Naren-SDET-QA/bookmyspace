-- Server-side, role-scoped revenue analytics. No transactional data is added.
create or replace function public.get_revenue_analytics(
  p_start_date date,
  p_end_date date,
  p_scope text default 'owner'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  result jsonb;
begin
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    raise exception 'invalid analytics date range' using errcode = '22023';
  end if;
  if p_scope not in ('admin', 'owner') then
    raise exception 'invalid analytics scope' using errcode = '22023';
  end if;
  if p_scope = 'admin' then
    if not (public.has_role(auth.uid(), 'administrator')
      or public.has_role(auth.uid(), 'super_administrator')) then
      raise exception 'analytics_admin_required' using errcode = '42501';
    end if;
  elsif not exists (
    select 1 from public.organizations o
    where o.owner_user_id = auth.uid() and o.deleted_at is null
  ) then
    raise exception 'analytics_owner_required' using errcode = '42501';
  end if;

  with base as (
    select
      b.id,
      b.book_date,
      b.status::text as booking_status,
      v.name as venue_name,
      coalesce(c.name, 'Uncategorized') as category_name,
      coalesce(pay.captured_amount, 0)::numeric as revenue,
      coalesce(ref.refund_amount, 0)::numeric as refund_amount,
      coalesce(pay.captured_amount, 0) > 0 as captured
    from public.bookings b
    join public.venues v on v.id = b.venue_id
    left join public.venue_categories c on c.id = v.category_id
    left join lateral (
      select sum(p.amount) as captured_amount
      from public.payments p
      where p.booking_id = b.id and p.status = 'captured'
    ) pay on true
    left join lateral (
      select sum(r.amount) as refund_amount
      from public.refunds r
      where r.booking_id = b.id and r.status = 'processed'
    ) ref on true
    where b.book_date between p_start_date and p_end_date
      and (
        p_scope = 'admin'
        or exists (
          select 1 from public.organizations o
          where o.id = v.org_id
            and o.owner_user_id = auth.uid()
            and o.deleted_at is null
        )
      )
  ), successful as (
    select * from base
    where captured and booking_status <> 'cancelled'
  ), daily as (
    select to_char(book_date, 'YYYY-MM-DD') label,
      sum(revenue) value, count(*) count from successful group by 1 order by 1
  ), weekly as (
    select to_char(date_trunc('week', book_date), 'YYYY-MM-DD') label,
      sum(revenue) value, count(*) count from successful group by 1 order by 1
  ), monthly as (
    select to_char(date_trunc('month', book_date), 'YYYY-MM') label,
      sum(revenue) value, count(*) count from successful group by 1 order by 1
  ), booking_trend as (
    select to_char(book_date, 'YYYY-MM-DD') label,
      0::numeric value, count(*) count from base group by 1 order by 1
  ), categories as (
    select category_name label, sum(revenue) value, count(*) count
      from successful group by 1 order by 2 desc
  ), venues as (
    select venue_name label, sum(revenue) value, count(*) count
      from successful group by 1 order by 2 desc
  )
  select jsonb_build_object(
    'total_revenue', coalesce((select sum(revenue) from successful), 0),
    'successful_bookings', (select count(*) from successful),
    'cancelled_bookings', (select count(*) from base where booking_status = 'cancelled'),
    'refund_amount', coalesce((select sum(refund_amount) from base), 0),
    'net_revenue', coalesce((select sum(revenue - refund_amount) from successful), 0),
    'average_booking_value', coalesce((select avg(revenue) from successful), 0),
    'daily_revenue', coalesce((select jsonb_agg(to_jsonb(daily)) from daily), '[]'::jsonb),
    'weekly_revenue', coalesce((select jsonb_agg(to_jsonb(weekly)) from weekly), '[]'::jsonb),
    'monthly_revenue', coalesce((select jsonb_agg(to_jsonb(monthly)) from monthly), '[]'::jsonb),
    'booking_trend', coalesce((select jsonb_agg(to_jsonb(booking_trend)) from booking_trend), '[]'::jsonb),
    'category_revenue', coalesce((select jsonb_agg(to_jsonb(categories)) from categories), '[]'::jsonb),
    'venue_revenue', coalesce((select jsonb_agg(to_jsonb(venues)) from venues), '[]'::jsonb)
  ) into result;
  return result;
end;
$$;

grant execute on function public.get_revenue_analytics(date, date, text)
  to authenticated;

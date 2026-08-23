-- Read-only SQL Editor verification for bookmyspace-dev
select c.slug, count(v.id) as seeded_venues
from public.venue_categories c
left join public.venues v on v.category_id=c.id and v.slug like 'bms-dev-e2e-%'
where c.slug in ('function_hall','hotel_stay','pg_coliving','institute')
group by c.slug order by c.slug;

select count(*) as duplicate_seed_slugs
from (select slug from public.venues where slug like 'bms-dev-e2e-%' group by slug having count(*)>1) d;

select count(*) as invalid_location_references
from public.venues v left join public.location_nodes l on l.id=v.location_node_id
where v.slug like 'bms-dev-e2e-%' and l.id is null;

select count(distinct o.owner_user_id) as owner_count
from public.venues v join public.organizations o on o.id=v.org_id
where v.slug like 'bms-dev-e2e-%';

select code,is_active,case when now() between starts_at and ends_at then 'active_now' when starts_at>now() then 'future' else 'expired' end as lifecycle
from public.coupons where code like 'BMSDEV%' order by code;

select b.status,p.status as payment_status,count(*)
from public.bookings b left join public.payments p on p.booking_id=b.id
where b.booking_ref like 'BMSDEV-%' group by b.status,p.status order by b.status,p.status;

select
 (select count(*) from public.refunds where booking_id in (select id from public.bookings where booking_ref like 'BMSDEV-%')) as refunds,
 (select count(*) from public.invoice_documents where invoice_number like 'BMSDEV-%') as invoices,
 (select count(*) from public.booking_check_ins where booking_id in (select id from public.bookings where booking_ref like 'BMSDEV-%')) as check_ins,
 (select count(*) from public.email_outbox where event_key like 'bms-dev-e2e:%') as email_events,
 (select count(*) from public.notifications where data->>'seed'='e2e_v1') as notifications;

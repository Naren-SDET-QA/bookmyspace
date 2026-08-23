-- Read-only DEV E2E prerequisite diagnostics.
-- Target: bookmyspace-dev / zykxneztahxbjduagutv
-- This file contains SELECTs only. It never creates Auth users or modifies data.

-- 1. Existing DEV customer account required by the seed.
select
  u.id,
  u.email,
  case when u.id is null then 'MISSING' else 'PRESENT' end as status
from (values ('customer.dev@bookmyspace.app'), ('customer@demo.com')) expected(email)
left join auth.users u on lower(u.email)=lower(expected.email)
order by expected.email;

-- 2-3. Exact owner lookup used by seed_dev_e2e.sql.
select
  op.user_id,
  op.email,
  op.name,
  ur.role::text as role,
  case when ur.revoked_at is null then 'active' else 'revoked' end as role_status,
  ur.revoked_at
from public.owner_profiles op
left join public.user_roles ur on ur.user_id=op.user_id
  and ur.role in ('venue_owner','institute_owner','event_organizer')
order by op.email, ur.role::text;

-- Exact eligible owner count used by the seed: distinct active owner-role users,
-- capped at two by the seed query.
select count(distinct op.user_id) as eligible_owner_count,
       case when count(distinct op.user_id) >= 2 then 'READY' else 'MISSING_TWO_ACTIVE_OWNERS' end as prerequisite_status
from public.owner_profiles op
join public.user_roles ur on ur.user_id=op.user_id
where ur.role in ('venue_owner','institute_owner','event_organizer')
  and ur.revoked_at is null;

-- 4. Approved active location nodes eligible for venue assignment.
select id, level, name, parent_id, country_code,
       coalesce(metadata->>'postal_code', metadata->>'pincode') as postal_code
from public.location_nodes
where status='active'
  and approved_at is not null
  and level in ('city_town','area_locality')
order by level, name, id;

select count(*) as approved_active_city_area_count,
       case when count(*) >= 4 then 'READY' else 'MISSING_FOUR_APPROVED_LOCATIONS' end as prerequisite_status
from public.location_nodes
where status='active'
  and approved_at is not null
  and level in ('city_town','area_locality');

-- 5. Required category families and the exact candidate rows available.
select id, slug, name, icon,
       case
         when slug='function_hall' then 'function_hall'
         when slug in ('hotel_stay','hotel','lodge') then 'hotel_lodge'
         when slug in ('pg_coliving','pg_hostel','hostel','co_living') then 'pg_coliving'
         when slug in ('institute','coaching') then 'institute_coaching'
       end as seed_family,
       case when metadata is null then 'metadata_missing' else 'metadata_present' end as metadata_status
from public.venue_categories
where slug in ('function_hall','hotel_stay','hotel','lodge',
               'pg_coliving','pg_hostel','hostel','co_living',
               'institute','coaching')
order by seed_family, slug;

-- 6. One compact missing-prerequisite report.
with checks as (
  select 'customer_auth' as prerequisite,
    exists(select 1 from auth.users where lower(email) in ('customer.dev@bookmyspace.app','customer@demo.com')) as ok
  union all
  select 'two_active_owner_roles',
    (select count(distinct op.user_id) >= 2
     from public.owner_profiles op join public.user_roles ur on ur.user_id=op.user_id
     where ur.role in ('venue_owner','institute_owner','event_organizer') and ur.revoked_at is null)
  union all
  select 'four_approved_active_city_or_area_nodes',
    (select count(*) >= 4 from public.location_nodes where status='active' and approved_at is not null and level in ('city_town','area_locality'))
  union all
  select 'function_hall_category', exists(select 1 from public.venue_categories where slug='function_hall')
  union all
  select 'hotel_lodge_category', exists(select 1 from public.venue_categories where slug in ('hotel_stay','hotel','lodge'))
  union all
  select 'pg_coliving_category', exists(select 1 from public.venue_categories where slug in ('pg_coliving','pg_hostel','hostel','co_living'))
  union all
  select 'institute_coaching_category', exists(select 1 from public.venue_categories where slug in ('institute','coaching'))
)
select prerequisite, case when ok then 'READY' else 'MISSING' end as status
from checks
where not ok
order by prerequisite;

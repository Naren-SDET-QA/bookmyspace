-- BookMySpace DEV E2E fixture seed (e2e_v1)
--
-- Run only with psql and an explicit DEV guard:
--   psql "$DEV_DATABASE_URL" -v bms_dev=1 -v bms_project_ref=zykxneztahxbjduagutv -f supabase/seed_dev_e2e.sql
--
-- This script never creates auth users and never imports location data. It
-- requires the existing DEV migrations, owner accounts, customer account and
-- approved location nodes. All identities are deterministic and rerunnable.
-- The four category loops are equivalent to bounded generate_series(1, 10).
-- All rows are synthetic_fixture data and are identified by the e2e_v1 marker.

\if :{?bms_dev}
\else
  \echo 'REFUSED: pass -v bms_dev=1 for the local/DEV database only.'
  \quit 3
\endif
\if :bms_dev
\else
  \echo 'REFUSED: bms_dev must equal 1.'
  \quit 3
\endif
\if :{?bms_project_ref}
\else
  \echo 'REFUSED: pass -v bms_project_ref=zykxneztahxbjduagutv.'
  \quit 3
\endif

do $$
begin
  if :'bms_project_ref' <> 'zykxneztahxbjduagutv' then
    raise exception 'REFUSED: Supabase project ref does not match DEV';
  end if;
end $$;

begin;

do $$
declare
  v_missing text[] := '{}';
  v_table text;
begin
  foreach v_table in array array[
    'venue_categories','venues','venue_images','venue_facilities',
    'venue_operating_hours','time_slots','bookings','payments','refunds',
    'coupons','notifications','email_outbox','invoice_documents',
    'booking_check_ins','location_nodes','organizations','owner_profiles'
  ] loop
    if to_regclass('public.' || v_table) is null then
      v_missing := array_append(v_missing, v_table);
    end if;
  end loop;
  if coalesce(array_length(v_missing, 1), 0) > 0 then
    raise exception 'DEV E2E seed prerequisites missing tables: %', array_to_string(v_missing, ', ');
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='venue_categories' and column_name='metadata') then
    raise exception 'DEV E2E seed requires the category metadata migration; no rows were written';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='venues' and column_name='location_node_id') then
    raise exception 'DEV E2E seed requires venues.location_node_id; no rows were written';
  end if;
end $$;

do $$
declare
  r record;
  v_customer uuid;
  v_owners uuid[];
  v_owner uuid;
  v_org uuid;
  v_category uuid;
  v_slug text;
  v_venue_slug text;
  v_location uuid;
  v_city text;
  v_state text;
  v_postal text;
  v_venue uuid;
  v_slot uuid;
  v_booking uuid;
  v_payment uuid;
  v_refund uuid;
  v_invoice uuid;
  v_count int;
  v_i int;
  v_category_no int;
  v_path record;
  v_cat_ids uuid[];
  v_cat_slugs text[] := array['function_hall','hotel_stay','pg_coliving','institute'];
begin
  select u.id into v_customer
  from auth.users u
  where lower(u.email) in ('customer.dev@bookmyspace.app','customer@demo.com')
  order by u.created_at limit 1;
  if v_customer is null then
    raise exception 'DEV E2E prerequisite missing: dedicated customer auth user';
  end if;

  select array_agg(x.user_id order by x.user_id) into v_owners
  from (
    select distinct op.user_id
    from public.owner_profiles op
    join public.user_roles ur on ur.user_id = op.user_id
    where ur.role in ('venue_owner','institute_owner','event_organizer')
      and ur.revoked_at is null
    limit 2
  ) x;
  if coalesce(array_length(v_owners, 1), 0) < 2 then
    raise exception 'DEV E2E prerequisite missing: two existing owner accounts/roles';
  end if;

  if (select count(*) from public.location_nodes where status='active' and approved_at is not null and level in ('city_town','area_locality')) < 4 then
    raise exception 'DEV E2E prerequisite missing: at least four approved city/area location nodes';
  end if;

  -- Update only existing category rows. No category is invented by this seed.
  for r in
    select c.id, c.slug, row_number() over (order by c.slug)::int as n
    from public.venue_categories c
    where c.slug in ('function_hall','marriage_hall','hotel_stay','hotel','lodge',
                     'pg_coliving','pg_hostel','hostel','co_living','institute','coaching')
  loop
    if r.slug in ('function_hall','marriage_hall') and not exists (select 1 from public.venue_categories where slug in ('function_hall','marriage_hall')) then continue; end if;
    update public.venue_categories
    set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'registration_required', r.slug in ('hotel_stay','hotel','lodge','institute','coaching'),
      'kyc_required', r.slug in ('institute','coaching'),
      'registration_required_fields', case when r.slug in ('institute','coaching') then jsonb_build_array('legal_name','identity_document') else jsonb_build_array('contact_name') end,
      'registration_optional_fields', jsonb_build_array('website','description'),
      'bookable', true,
      'searchable', true,
      'visible_in_home', true,
      'dev_fixture_seed', 'e2e_v1'
    )
    where id=r.id;
  end loop;

  -- One deterministic organization per existing owner.
  foreach v_owner in array v_owners loop
    v_org := md5('bms-dev-e2e:org:' || v_owner::text)::uuid;
    insert into public.organizations (id, owner_user_id, org_type, name, country, is_active)
    values (v_org, v_owner, 'venue_owner', 'DEV E2E Organisation ' || left(v_owner::text, 8), 'IN', true)
    on conflict (id) do update set is_active=true, updated_at=now();
  end loop;

  select array[
    (select id from public.venue_categories where slug='function_hall' limit 1),
    (select id from public.venue_categories where slug in ('hotel_stay','hotel','lodge') order by case slug when 'hotel_stay' then 1 when 'hotel' then 2 else 3 end limit 1),
    (select id from public.venue_categories where slug in ('pg_coliving','pg_hostel','hostel','co_living') order by case slug when 'pg_coliving' then 1 when 'pg_hostel' then 2 else 3 end limit 1),
    (select id from public.venue_categories where slug in ('institute','coaching') order by case slug when 'institute' then 1 else 2 end limit 1)
  ] into v_cat_ids;
  if exists (select 1 from unnest(v_cat_ids) x where x is null) then
    raise exception 'DEV E2E prerequisite missing one or more categories: function_hall, hotel/hotel_stay, pg/co-living, institute/coaching';
  end if;
  for v_category_no in 1..4 loop
    v_category := v_cat_ids[v_category_no];
    v_slug := v_cat_slugs[v_category_no];
    for v_i in 1..10 loop
      select ln.id into v_location
      from public.location_nodes ln
      where ln.status='active' and ln.approved_at is not null and ln.level in ('city_town','area_locality')
      order by ln.id offset ((v_i + v_category_no - 2) % (select count(*) from public.location_nodes where status='active' and approved_at is not null and level in ('city_town','area_locality'))) limit 1;

      with recursive ancestors as (
        select id,parent_id,level,name,metadata from public.location_nodes where id=v_location
        union all select n.id,n.parent_id,n.level,n.name,n.metadata from public.location_nodes n join ancestors a on n.id=a.parent_id
      )
      select coalesce(max(name) filter(where level='city_town'), max(name) filter(where level='area_locality'), 'DEV Location'),
             coalesce(max(name) filter(where level='state_province'), 'IN'),
             coalesce(max(metadata->>'postal_code') filter(where metadata ? 'postal_code'), max(metadata->>'pincode') filter(where metadata ? 'pincode'))
      into v_city, v_state, v_postal from ancestors;
      v_owner := v_owners[1 + ((v_i + v_category_no) % 2)];
      v_org := md5('bms-dev-e2e:org:' || v_owner::text)::uuid;
      v_venue_slug := 'bms-dev-e2e-' || v_slug || '-' || lpad(v_i::text,2,'0');
      v_venue := md5('bms-dev-e2e:venue:' || v_slug || ':' || v_i::text)::uuid;
      insert into public.venues (id,org_id,category_id,name,slug,description,city,state,postal_code,country,
        location_node_id,capacity,pricing_base_amount,pricing_currency,tax_rate,is_verified,is_active,avg_rating,rating_count,listing_status)
      values (v_venue,v_org,v_category,initcap(replace(v_slug,'_',' ')) || ' DEV ' || v_i,v_venue_slug,
        'Deterministic BookMySpace DEV E2E fixture.',v_city,v_state,v_postal,'IN',v_location,
        50 + v_i*10,1000 + v_i*250,'INR',5,true,true,3.5 + (v_i % 15)/10.0,10+v_i,'published')
      on conflict (id) do update set org_id=excluded.org_id,category_id=excluded.category_id,name=excluded.name,
        city=excluded.city,state=excluded.state,postal_code=excluded.postal_code,location_node_id=excluded.location_node_id,
        capacity=excluded.capacity,pricing_base_amount=excluded.pricing_base_amount,is_active=true,listing_status='published';
      insert into public.venue_images (id,venue_id,url,thumbnail_url,alt_text,is_cover,sort_order)
      values (md5(v_venue_slug||':image:1')::uuid,v_venue,'https://images.unsplash.com/photo-1519167758481-83f550bb49b3','https://images.unsplash.com/photo-1519167758481-83f550bb49b3','DEV fixture',true,1)
      on conflict (id) do update set url=excluded.url,thumbnail_url=excluded.thumbnail_url;
      insert into public.venue_images (id,venue_id,url,thumbnail_url,alt_text,is_cover,sort_order)
      values (md5(v_venue_slug||':image:2')::uuid,v_venue,'https://images.unsplash.com/photo-1497366811353-6870744d04b2','https://images.unsplash.com/photo-1497366811353-6870744d04b2','DEV fixture',false,2),
             (md5(v_venue_slug||':image:3')::uuid,v_venue,'https://images.unsplash.com/photo-1540575467063-178a50c2df87','https://images.unsplash.com/photo-1540575467063-178a50c2df87','DEV fixture',false,3)
      on conflict (id) do update set url=excluded.url,thumbnail_url=excluded.thumbnail_url;
      insert into public.venue_facilities (id,venue_id,facility,is_available) values
        (md5(v_venue_slug||':wifi')::uuid,v_venue,'WiFi',true),(md5(v_venue_slug||':parking')::uuid,v_venue,'Parking',true)
      on conflict (venue_id,facility) do update set is_available=true;
      insert into public.time_slots (id,venue_id,label,start_time,end_time,price_amount,is_active)
      values (md5(v_venue_slug||':slot:1')::uuid,v_venue,'Morning','09:00','13:00',1000+v_i*100,true)
      on conflict (id) do update set price_amount=excluded.price_amount,is_active=true;
      insert into public.venue_operating_hours (id,venue_id,day_of_week,opens_at,closes_at,is_closed)
      values (md5(v_venue_slug||':hours:1')::uuid,v_venue,1,'08:00','22:00',false)
      on conflict (venue_id,day_of_week) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,is_closed=false;
    end loop;
  end loop;

  -- Offers: active, future and expired, all deterministic and safe to rerun.
  insert into public.coupons (id,code,description,discount_type,discount_value,starts_at,ends_at,is_active)
  values (md5('bms-dev-e2e:offer:active')::uuid,'BMSDEVACTIVE','DEV active offer','percentage',10,now()-interval '1 day',now()+interval '30 days',true),
         (md5('bms-dev-e2e:offer:future')::uuid,'BMSDEVFUTURE','DEV future offer','fixed',250,now()+interval '7 days',now()+interval '30 days',true),
         (md5('bms-dev-e2e:offer:expired')::uuid,'BMSDEVEXPIRED','DEV expired offer','percentage',5,now()-interval '30 days',now()-interval '1 day',false)
  on conflict (id) do update set is_active=excluded.is_active,starts_at=excluded.starts_at,ends_at=excluded.ends_at;

  -- Four bookings exercise confirmed/captured, cancelled/refunded, invoice,
  -- notification, email outbox and QR/check-in paths without fake aggregates.
  select v.id into v_venue from public.venues v where v.slug='bms-dev-e2e-function_hall-01';
  if v_venue is not null then
    v_slot := md5('bms-dev-e2e:function_hall:01:slot:1')::uuid;
    v_booking := md5('bms-dev-e2e:booking:confirmed')::uuid;
    insert into public.bookings (id,booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,quantity,amount,tax_amount,discount_amount,total_amount,confirmed_at,metadata)
    values(v_booking,'BMSDEV-CONFIRMED',v_customer,v_venue,v_slot,current_date-3,'09:00','13:00','confirmed',1,1000,50,0,1050,now(),jsonb_build_object('seed','e2e_v1'))
    on conflict (id) do update set status='confirmed',total_amount=excluded.total_amount,metadata=excluded.metadata;
    v_payment := md5('bms-dev-e2e:payment:confirmed')::uuid;
    insert into public.payments(id,booking_id,user_id,provider,provider_order_id,provider_payment_id,amount,status,method,is_refundable)
    values(v_payment,v_booking,v_customer,'razorpay','bmsdev-order-confirmed','bmsdev-pay-confirmed',1050,'captured','test',true)
    on conflict(id) do update set status='captured',amount=excluded.amount;
    v_invoice := md5('bms-dev-e2e:invoice:confirmed')::uuid;
    insert into public.invoice_documents(id,invoice_number,booking_id,payment_id,storage_path,status,generated_at)
    values(v_invoice,'BMSDEV-INV-001',v_booking,v_payment,'dev/e2e/BMSDEV-INV-001.pdf','generated',now())
    on conflict(id) do update set status='generated',generated_at=now();
    insert into public.notifications(id,user_id,type,title,body,data) values(md5('bms-dev-e2e:notification:confirmed')::uuid,v_customer,'booking_confirmed','DEV booking confirmed','Fixture booking',jsonb_build_object('booking_id',v_booking)) on conflict(id) do nothing;
    insert into public.email_outbox(id,event_key,event_type,recipient_email,booking_id,template_name,payload,status) values(md5('bms-dev-e2e:email:confirmed')::uuid,'bms-dev-e2e:email:confirmed','booking_confirmed','customer.dev@bookmyspace.app',v_booking,'booking-confirmed',jsonb_build_object('seed','e2e_v1'),'pending') on conflict(id) do update set status='pending';
    insert into public.booking_check_ins(id,booking_id,checked_in_by,method) values(md5('bms-dev-e2e:checkin:confirmed')::uuid,v_booking,v_customer,'qr') on conflict(id) do nothing;

    v_booking := md5('bms-dev-e2e:booking:cancelled')::uuid;
    insert into public.bookings (id,booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,quantity,amount,tax_amount,discount_amount,total_amount,cancelled_at,metadata)
    values(v_booking,'BMSDEV-CANCELLED',v_customer,v_venue,v_slot,current_date-10,'09:00','13:00','cancelled',1,1200,60,0,1260,now(),jsonb_build_object('seed','e2e_v1'))
    on conflict (id) do update set status='cancelled',total_amount=excluded.total_amount,metadata=excluded.metadata;
    v_payment := md5('bms-dev-e2e:payment:cancelled')::uuid;
    insert into public.payments(id,booking_id,user_id,provider,provider_order_id,provider_payment_id,amount,status,method,is_refundable)
    values(v_payment,v_booking,v_customer,'razorpay','bmsdev-order-cancelled','bmsdev-pay-cancelled',1260,'captured','test',true)
    on conflict(id) do update set status='captured',amount=excluded.amount;
    v_refund := md5('bms-dev-e2e:refund:cancelled')::uuid;
    insert into public.refunds(id,payment_id,booking_id,amount,reason,status,provider_refund_id,processed_at)
    values(v_refund,v_payment,v_booking,1260,'DEV E2E cancellation','processed','bmsdev-refund-cancelled',now())
    on conflict(id) do update set status='processed',amount=excluded.amount,processed_at=now();
  end if;
end $$;

commit;

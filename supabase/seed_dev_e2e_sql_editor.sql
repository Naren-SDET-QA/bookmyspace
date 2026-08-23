-- BookMySpace DEV E2E seed for the Supabase SQL Editor.
-- Target project: bookmyspace-dev
-- Target project ref: zykxneztahxbjduagutv
--
-- SQL Editor has no psql variables or portable PostgreSQL setting exposing the
-- Supabase project ref. Open this script only in the SQL Editor for the target
-- project. The database guard below rejects non-PostgreSQL/non-postgres DBs.
-- This file intentionally contains no psql commands or destructive cleanup,
-- or auth.users inserts.

begin;

do $$
begin
  if current_database() <> 'postgres' then
    raise exception 'REFUSED: expected Supabase postgres database';
  end if;
  if current_user not in ('postgres', 'supabase_admin') then
    raise exception 'REFUSED: SQL Editor seed requires an administrative database role';
  end if;
  if to_regclass('public.venues') is null
     or to_regclass('public.venue_categories') is null
     or to_regclass('public.location_nodes') is null then
    raise exception 'REFUSED: BookMySpace schema is not present';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='venue_categories' and column_name='metadata') then
    raise exception 'REFUSED: category metadata migration is required';
  end if;
end $$;

do $$
declare
  v_customer uuid;
  v_owners uuid[];
  v_categories uuid[];
  v_category_slugs text[] := array['function_hall','hotel_stay','pg_coliving','institute'];
  v_owner uuid;
  v_org uuid;
  v_category uuid;
  v_location uuid;
  v_venue uuid;
  v_slot uuid;
  v_payment uuid;
  v_booking uuid;
  v_slug text;
  v_city text;
  v_state text;
  v_postal text;
  v_i int;
  v_family int;
begin
  select id into v_customer
  from auth.users
  where lower(email) in ('customer.dev@bookmyspace.app','customer@demo.com')
  order by created_at limit 1;
  if v_customer is null then
    raise exception 'REFUSED: existing DEV customer account is required';
  end if;

  select array_agg(user_id order by user_id) into v_owners
  from (
    select distinct op.user_id
    from public.owner_profiles op
    join public.user_roles ur on ur.user_id=op.user_id
    where ur.role in ('venue_owner','institute_owner','event_organizer')
      and ur.revoked_at is null
    limit 2
  ) owners;
  if coalesce(array_length(v_owners,1),0) < 2 then
    raise exception 'REFUSED: two existing DEV owner accounts are required';
  end if;

  if (select count(*) from public.location_nodes
      where status='active' and approved_at is not null
        and level in ('city_town','area_locality')) < 4 then
    raise exception 'REFUSED: four approved existing location nodes are required';
  end if;

  select array[
    (select id from public.venue_categories where slug='function_hall' limit 1),
    (select id from public.venue_categories where slug in ('hotel_stay','hotel','lodge') order by slug limit 1),
    (select id from public.venue_categories where slug in ('pg_coliving','pg_hostel','hostel','co_living') order by slug limit 1),
    (select id from public.venue_categories where slug in ('institute','coaching') order by slug limit 1)
  ] into v_categories;
  if exists (select 1 from unnest(v_categories) x where x is null) then
    raise exception 'REFUSED: required existing category family is missing';
  end if;

  update public.venue_categories
  set metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object(
    'registration_required',slug in ('hotel_stay','hotel','lodge','institute','coaching'),
    'kyc_required',slug in ('institute','coaching'),
    'registration_required_fields',case when slug in ('institute','coaching') then jsonb_build_array('legal_name','identity_document') else jsonb_build_array('contact_name') end,
    'registration_optional_fields',jsonb_build_array('website','description'),
    'bookable',true,'searchable',true,'visible_in_home',true,'dev_fixture_seed','e2e_v1')
  where id in (select unnest(v_categories));

  for v_family in 1..4 loop
    v_category := v_categories[v_family];
    for v_i in 1..10 loop
      select id into v_location
      from public.location_nodes
      where status='active' and approved_at is not null
        and level in ('city_town','area_locality')
      order by id
      offset ((v_i + v_family - 2) % (select count(*) from public.location_nodes where status='active' and approved_at is not null and level in ('city_town','area_locality')))
      limit 1;

      select name, name, coalesce(metadata->>'postal_code', metadata->>'pincode')
      into v_city, v_state, v_postal
      from public.location_nodes where id=v_location;
      v_owner := v_owners[1 + ((v_i + v_family) % 2)];
      v_org := md5('bms-dev-e2e:org:'||v_owner::text)::uuid;
      v_slug := 'bms-dev-e2e-'||v_category_slugs[v_family]||'-'||lpad(v_i::text,2,'0');
      v_venue := md5('bms-dev-e2e:venue:'||v_category_slugs[v_family]||':'||v_i::text)::uuid;

      insert into public.organizations(id,owner_user_id,org_type,name,country,is_active)
      values(v_org,v_owner,'venue_owner','DEV E2E Organisation '||left(v_owner::text,8),'IN',true)
      on conflict(id) do update set is_active=true,updated_at=now();

      insert into public.venues(id,org_id,category_id,name,slug,description,city,state,postal_code,country,location_node_id,capacity,pricing_base_amount,pricing_currency,tax_rate,is_verified,is_active,avg_rating,rating_count,listing_status)
      values(v_venue,v_org,v_category,initcap(replace(v_category_slugs[v_family],'_',' '))||' DEV '||v_i,v_slug,'Deterministic DEV E2E fixture',v_city,v_state,v_postal,'IN',v_location,50+v_i*10,1000+v_i*250,'INR',5,true,true,3.5+(v_i%15)/10.0,10+v_i,'published')
      on conflict(id) do update set org_id=excluded.org_id,category_id=excluded.category_id,name=excluded.name,location_node_id=excluded.location_node_id,pricing_base_amount=excluded.pricing_base_amount,is_active=true,listing_status='published';

      insert into public.venue_images(id,venue_id,url,thumbnail_url,alt_text,is_cover,sort_order)
      values(md5(v_slug||':image:1')::uuid,v_venue,'https://images.unsplash.com/photo-1519167758481-83f550bb49b3','https://images.unsplash.com/photo-1519167758481-83f550bb49b3','DEV fixture',true,1)
      on conflict(id) do update set url=excluded.url,thumbnail_url=excluded.thumbnail_url;
      insert into public.venue_images(id,venue_id,url,thumbnail_url,alt_text,is_cover,sort_order)
      values(md5(v_slug||':image:2')::uuid,v_venue,'https://images.unsplash.com/photo-1497366811353-6870744d04b2','https://images.unsplash.com/photo-1497366811353-6870744d04b2','DEV fixture',false,2),
            (md5(v_slug||':image:3')::uuid,v_venue,'https://images.unsplash.com/photo-1540575467063-178a50c2df87','https://images.unsplash.com/photo-1540575467063-178a50c2df87','DEV fixture',false,3)
      on conflict(id) do update set url=excluded.url,thumbnail_url=excluded.thumbnail_url;
      insert into public.venue_facilities(id,venue_id,facility,is_available)
      values(md5(v_slug||':wifi')::uuid,v_venue,'WiFi',true),(md5(v_slug||':parking')::uuid,v_venue,'Parking',true)
      on conflict(venue_id,facility) do update set is_available=true;
      insert into public.time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active)
      values(md5(v_slug||':slot:1')::uuid,v_venue,'Morning','09:00','13:00',1000+v_i*100,true)
      on conflict(id) do update set is_active=true,price_amount=excluded.price_amount;
      insert into public.venue_operating_hours(id,venue_id,day_of_week,opens_at,closes_at,is_closed)
      values(md5(v_slug||':hours:1')::uuid,v_venue,1,'08:00','22:00',false)
      on conflict(venue_id,day_of_week) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,is_closed=false;
    end loop;
  end loop;

  insert into public.coupons(id,code,description,discount_type,discount_value,starts_at,ends_at,is_active)
  values(md5('bms-dev-e2e:offer:active')::uuid,'BMSDEVACTIVE','DEV active offer','percentage',10,now()-interval '1 day',now()+interval '30 days',true),
        (md5('bms-dev-e2e:offer:future')::uuid,'BMSDEVFUTURE','DEV future offer','fixed',250,now()+interval '7 days',now()+interval '30 days',true),
        (md5('bms-dev-e2e:offer:expired')::uuid,'BMSDEVEXPIRED','DEV expired offer','percentage',5,now()-interval '30 days',now()-interval '1 day',false)
  on conflict(id) do update set is_active=excluded.is_active,starts_at=excluded.starts_at,ends_at=excluded.ends_at;

  -- Transactional fixtures use the deterministic first function-hall venue.
  select id into v_venue from public.venues where slug='bms-dev-e2e-function_hall-01';
  if v_venue is not null then
    v_slot := md5('bms-dev-e2e-function_hall-01:slot:1')::uuid;
    insert into public.time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active)
    values(v_slot,v_venue,'Morning','09:00','13:00',1000,true)
    on conflict(id) do update set is_active=true;
    v_booking := md5('bms-dev-e2e:booking:confirmed')::uuid;
    insert into public.bookings(id,booking_ref,user_id,venue_id,slot_id,status,quantity,amount,tax_amount,discount_amount,total_amount,book_date,start_time,end_time,confirmed_at,metadata)
    values(v_booking,'BMSDEV-CONFIRMED',v_customer,v_venue,v_slot,'confirmed',1,1000,50,0,1050,current_date-3,'09:00','13:00',now(),jsonb_build_object('seed','e2e_v1'))
    on conflict(id) do update set status='confirmed',total_amount=excluded.total_amount;
    v_payment := md5('bms-dev-e2e:payment:confirmed')::uuid;
    insert into public.payments(id,booking_id,user_id,provider,provider_order_id,provider_payment_id,amount,status,method,is_refundable)
    values(v_payment,v_booking,v_customer,'razorpay','bmsdev-order-confirmed','bmsdev-pay-confirmed',1050,'captured','test',true)
    on conflict(id) do update set status='captured';
    insert into public.invoice_documents(id,invoice_number,booking_id,payment_id,storage_path,status,generated_at)
    values(md5('bms-dev-e2e:invoice:confirmed')::uuid,'BMSDEV-INV-001',v_booking,v_payment,'dev/e2e/BMSDEV-INV-001.pdf','generated',now())
    on conflict(id) do update set status='generated';
    insert into public.notifications(id,user_id,type,title,body,data)
    values(md5('bms-dev-e2e:notification:confirmed')::uuid,v_customer,'booking_confirmed','DEV booking confirmed','Fixture booking',jsonb_build_object('seed','e2e_v1'))
    on conflict(id) do nothing;
    insert into public.email_outbox(id,event_key,event_type,recipient_email,booking_id,template_name,payload,status)
    values(md5('bms-dev-e2e:email:confirmed')::uuid,'bms-dev-e2e:email:confirmed','booking_confirmed','customer.dev@bookmyspace.app',v_booking,'booking-confirmed',jsonb_build_object('seed','e2e_v1'),'pending')
    on conflict(id) do update set status='pending';
    insert into public.booking_check_ins(id,booking_id,checked_in_by,method)
    values(md5('bms-dev-e2e:checkin:confirmed')::uuid,v_booking,v_customer,'qr') on conflict(id) do nothing;
    v_booking := md5('bms-dev-e2e:booking:cancelled')::uuid;
    insert into public.bookings(id,booking_ref,user_id,venue_id,slot_id,status,quantity,amount,tax_amount,discount_amount,total_amount,book_date,start_time,end_time,cancelled_at,metadata)
    values(v_booking,'BMSDEV-CANCELLED',v_customer,v_venue,v_slot,'cancelled',1,1200,60,0,1260,current_date-10,'09:00','13:00',now(),jsonb_build_object('seed','e2e_v1'))
    on conflict(id) do update set status='cancelled',total_amount=excluded.total_amount;
    v_payment := md5('bms-dev-e2e:payment:cancelled')::uuid;
    insert into public.payments(id,booking_id,user_id,provider,provider_order_id,provider_payment_id,amount,status,method,is_refundable)
    values(v_payment,v_booking,v_customer,'razorpay','bmsdev-order-cancelled','bmsdev-pay-cancelled',1260,'captured','test',true)
    on conflict(id) do update set status='captured';
    insert into public.refunds(id,payment_id,booking_id,amount,reason,status,provider_refund_id,processed_at)
    values(md5('bms-dev-e2e:refund:cancelled')::uuid,v_payment,v_booking,1260,'DEV E2E cancellation','processed','bmsdev-refund-cancelled',now())
    on conflict(id) do update set status='processed';
  end if;
end $$;

commit;

-- TEMPORARY E2E TEST DATA. Idempotent and isolated by fixed UUIDs.
do $$
declare
  v_owner constant uuid := 'f50135a4-7d93-4add-abf7-0d7c253c78e2';
  v_org uuid;
begin
  select id into v_org from public.organizations
  where owner_user_id = v_owner and deleted_at is null order by created_at limit 1;
  if v_org is null then raise exception 'E2E owner organization is missing'; end if;

  insert into public.accommodation_properties
    (id,org_id,module,property_type,name,description,address,city,latitude,longitude,
     cover_image,photos,amenities,is_active,booking_mode,check_in_time,check_out_time,stay_rules)
  values
    ('e2e00000-0000-4000-8000-000000000001',v_org,'stay','hotel',
     'TEST Grand Residency - E2E TEST DATA',
     'E2E TEST DATA - modern hotel inventory for safe booking certification.',
     'Trunk Road, Bhagyanagar 5th Lane, Ongole, Prakasam District','Ongole',15.5057,80.0499,
     'https://placehold.co/1200x800/6750A4/FFFFFF?text=TEST+Grand+Residency',
     array['https://placehold.co/1200x800/6750A4/FFFFFF?text=E2E+TEST+Hotel'],
     array['WiFi','Air conditioning','Parking','Restaurant','Power backup','24-hour reception'],
     true,'instant','14:00','11:00','{"e2e_test_data":true,"cancellation":"Free until 24 hours before check-in"}')
  on conflict(id) do update set org_id=excluded.org_id,name=excluded.name,description=excluded.description,
    address=excluded.address,city=excluded.city,amenities=excluded.amenities,is_active=true,
    photos=excluded.photos,cover_image=excluded.cover_image,updated_at=now();

  insert into public.accommodation_units
    (id,property_id,name,occupancy_type,capacity,inventory,price_nightly,available_from,amenities,is_active,photos,max_adults,max_children)
  values
    ('e2e10000-0000-4000-8000-000000000001','e2e00000-0000-4000-8000-000000000001','Standard Room','standard',2,4,2200,current_date,array['Queen bed','WiFi','AC'],true,array['https://placehold.co/900x600?text=TEST+Standard'],2,1),
    ('e2e10000-0000-4000-8000-000000000002','e2e00000-0000-4000-8000-000000000001','Deluxe Room','deluxe',3,3,3200,current_date,array['King bed','WiFi','AC','Workspace'],true,array['https://placehold.co/900x600?text=TEST+Deluxe'],2,1),
    ('e2e10000-0000-4000-8000-000000000003','e2e00000-0000-4000-8000-000000000001','Suite','suite',4,2,4800,current_date,array['King bed','Living room','WiFi','AC','Mini fridge'],true,array['https://placehold.co/900x600?text=TEST+Suite'],3,1)
  on conflict(id) do update set name=excluded.name,inventory=excluded.inventory,price_nightly=excluded.price_nightly,
    available_from=current_date,amenities=excluded.amenities,is_active=true,photos=excluded.photos;

  insert into public.stay_physical_rooms(id,unit_id,room_code,is_active)
  select ('e2e2'||lpad(n::text,4,'0')||'-0000-4000-8000-'||right(replace(u.id::text,'-',''),12))::uuid,u.id,
    'E2E-'||case u.name when 'Standard Room' then 'STD' when 'Deluxe Room' then 'DLX' else 'STE' end||'-'||lpad(n::text,2,'0'),true
  from public.accommodation_units u cross join lateral generate_series(1,u.inventory)n
  where u.property_id='e2e00000-0000-4000-8000-000000000001'
  on conflict(unit_id,room_code) do update set is_active=true;

  insert into public.stay_rates(id,unit_id,start_date,end_date,nightly_rate,taxes,fees,discount)
  select ('e2e30000-0000-4000-8000-00000000000'||row_number() over(order by id))::uuid,
    id,current_date,current_date+59,price_nightly,
    '[{"name":"Test tax","type":"percent","value":5}]','[]',0
  from public.accommodation_units where property_id='e2e00000-0000-4000-8000-000000000001'
  on conflict(id) do update set start_date=current_date,end_date=current_date+59,nightly_rate=excluded.nightly_rate,taxes=excluded.taxes;

  insert into public.venues
    (id,org_id,category_id,name,slug,description,address_line1,city,state,postal_code,latitude,longitude,
     capacity,pricing_base_amount,is_verified,is_active,cancellation_policy)
  values
    ('e2e40000-0000-4000-8000-000000000001',v_org,(select id from venue_categories where slug='function_hall'),'TEST Sri Convention Hall - E2E TEST DATA','test-sri-convention-hall-e2e','E2E TEST DATA - convention hall for certification.','Kurnool Road, near RTC Bus Stand','Ongole','Andhra Pradesh','523002',15.5062,80.0441,800,75000,true,true,'{"e2e_test_data":true}'),
    ('e2e40000-0000-4000-8000-000000000002',v_org,(select id from venue_categories where slug='meeting_room'),'TEST Business Meeting Center - E2E TEST DATA','test-business-meeting-center-e2e','E2E TEST DATA - conference and training room.','Mangamuru Road, Lawyer Pet Extension','Ongole','Andhra Pradesh','523002',15.4938,80.0574,24,900,true,true,'{"e2e_test_data":true}'),
    ('e2e40000-0000-4000-8000-000000000003',v_org,(select id from venue_categories where slug='sports_ground'),'TEST Sports Arena - E2E TEST DATA','test-sports-arena-e2e','E2E TEST DATA - multi-sport turf and court.','Pelluru Road, Vengamukkapalem','Ongole','Andhra Pradesh','523272',15.4744,80.0680,40,1200,true,true,'{"e2e_test_data":true}'),
    ('e2e40000-0000-4000-8000-000000000004',v_org,(select id from venue_categories where slug='party_hall'),'TEST Celebration Hall - E2E TEST DATA','test-celebration-hall-e2e','E2E TEST DATA - function and event celebration hall.','Guntur Road, Islampet','Ongole','Andhra Pradesh','523001',15.5132,80.0394,350,45000,true,true,'{"e2e_test_data":true}')
  on conflict(id) do update set org_id=excluded.org_id,name=excluded.name,description=excluded.description,
    address_line1=excluded.address_line1,city=excluded.city,state=excluded.state,capacity=excluded.capacity,
    pricing_base_amount=excluded.pricing_base_amount,is_active=true,deleted_at=null,updated_at=now();

  insert into public.venue_images(venue_id,url,alt_text,is_cover,sort_order)
  select id,'https://placehold.co/1200x800/6750A4/FFFFFF?text='||replace(name,' ','+'),name||' placeholder',true,0
  from public.venues where id::text like 'e2e40000-0000-4000-8000-00000000000%'
  and not exists(select 1 from venue_images i where i.venue_id=venues.id and i.is_cover);

  insert into public.venue_facilities(venue_id,facility)
  select v.id,f from public.venues v cross join unnest(array['Parking','WiFi','Air conditioning','Power backup','Restrooms']) f
  where v.id::text like 'e2e40000-0000-4000-8000-00000000000%' on conflict(venue_id,facility) do update set is_available=true;

  insert into public.venue_operating_hours(venue_id,day_of_week,opens_at,closes_at,is_closed)
  select v.id,d,'06:00','23:00',false from public.venues v cross join generate_series(0,6)d
  where v.id::text like 'e2e40000-0000-4000-8000-00000000000%'
  on conflict(venue_id,day_of_week) do update set opens_at=excluded.opens_at,closes_at=excluded.closes_at,is_closed=false;

  insert into public.time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active) values
    ('e2e50000-0000-4000-8000-000000000001','e2e40000-0000-4000-8000-000000000001','Morning','08:00','14:00',75000,true),
    ('e2e50000-0000-4000-8000-000000000002','e2e40000-0000-4000-8000-000000000001','Evening','16:00','22:00',90000,true),
    ('e2e50000-0000-4000-8000-000000000003','e2e40000-0000-4000-8000-000000000002','Variable duration','00:00','23:59',900,true),
    ('e2e50000-0000-4000-8000-000000000004','e2e40000-0000-4000-8000-000000000003','Variable duration','00:00','23:59',1200,true),
    ('e2e50000-0000-4000-8000-000000000005','e2e40000-0000-4000-8000-000000000004','Day Event','09:00','15:00',45000,true),
    ('e2e50000-0000-4000-8000-000000000006','e2e40000-0000-4000-8000-000000000004','Evening Event','17:00','23:00',55000,true)
  on conflict(id) do update set label=excluded.label,start_time=excluded.start_time,end_time=excluded.end_time,price_amount=excluded.price_amount,is_active=true;

  insert into public.hall_booking_settings(venue_id,booking_mode,min_notice_minutes,max_advance_days,instant_book_window_hours,approval_timeout_minutes,checkout_hold_minutes)
  values ('e2e40000-0000-4000-8000-000000000001','instant',60,60,48,1440,10),('e2e40000-0000-4000-8000-000000000004','approval',60,60,48,1440,10)
  on conflict(venue_id) do update set max_advance_days=60,min_notice_minutes=60;

  insert into public.meeting_room_profiles(venue_id,room_type,hourly_rate,half_day_rate,full_day_rate,buffer_minutes,booking_mode,amenities)
  values('e2e40000-0000-4000-8000-000000000002','conference',900,3200,5800,15,'instant',array['WiFi','Projector','TV','AC','Whiteboard'])
  on conflict(venue_id) do update set hourly_rate=excluded.hourly_rate,half_day_rate=excluded.half_day_rate,full_day_rate=excluded.full_day_rate,amenities=excluded.amenities;

  insert into public.sports_venue_profiles(venue_id,sport_type,hourly_rate,session_minutes,session_rate,buffer_minutes,booking_mode,equipment,amenities)
  values('e2e40000-0000-4000-8000-000000000003','turf',1200,60,1200,15,'instant',array['Cricket stumps','Football goalposts','Badminton nets'],array['Floodlights','Parking','Changing room','Drinking water'])
  on conflict(venue_id) do update set hourly_rate=excluded.hourly_rate,session_rate=excluded.session_rate,equipment=excluded.equipment,amenities=excluded.amenities;
end $$;


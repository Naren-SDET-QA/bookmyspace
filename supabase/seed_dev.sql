-- ============================================================
-- BookMySpace — DEV Seed Data (V1 Scope Only)
-- File: supabase/seed_dev.sql
--
-- TARGET ENVIRONMENT: DEV Supabase Database Only
-- V1 SCOPE: Function Hall, Hotel/Stay, PG/Co-Living
--
-- SECURITY & INTEGRITY CONSTRAINTS:
--   * Idempotent & safe to re-run multiple times.
--   * Uses verified existing schema tables & columns only.
--   * No passwords, secrets, or real production data.
--   * Auth users must be created via Supabase Auth Admin/API.
--   * References auth.users by email lookup (e.g. owner.dev@bookmyspace.app).
--   * All synthetic payment & booking records are clearly tagged.
--   * Holds 0017 and 0018 migrations out of scope.
-- ============================================================

-- ------------------------------------------------------------
-- 1. CATEGORIES (Ensure V1 Categories Exist Idempotently)
-- ------------------------------------------------------------
insert into public.venue_categories (slug, name, icon) values
  ('function_hall', 'Function Hall', 'event_seat'),
  ('hotel_stay', 'Hotel / Stay', 'hotel'),
  ('pg_coliving', 'PG / Co-Living', 'apartment'),
  ('meeting_room', 'Meeting Room', 'meeting_room')
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- 2. ORGANIZATIONS (Linked to DEV Test Owner if present)
-- ------------------------------------------------------------
do $$
declare
  v_owner_id uuid;
  v_org_id uuid := 'd0000000-0000-4000-a000-000000000001'::uuid;
begin
  -- Lookup owner user ID by DEV test email, fallback to any demo user if found
  select id into v_owner_id from auth.users where email = 'owner.dev@bookmyspace.app';
  if v_owner_id is null then
    select id into v_owner_id from auth.users where email = 'owner@demo.com';
  end if;

  if v_owner_id is not null then
    insert into public.organizations (id, owner_user_id, org_type, name, commission_rate)
    values (v_org_id, v_owner_id, 'venue_owner', 'DEV Test Venues & Stays Org', 10.00)
    on conflict (id) do nothing;
  end if;
end $$;

-- ------------------------------------------------------------
-- 3. VENUES (V1: Function Hall, Hotel/Stay, PG/Co-Living)
-- ------------------------------------------------------------
do $$
declare
  v_org_id uuid := 'd0000000-0000-4000-a000-000000000001'::uuid;
  v_cat_fh uuid;
  v_cat_hotel uuid;
  v_cat_pg uuid;

  -- Fixed deterministic UUIDs for DEV venues (strictly valid hex)
  v_fh1_id uuid := 'd0000000-0000-4000-1000-000000000001'::uuid;
  v_fh2_id uuid := 'd0000000-0000-4000-1000-000000000002'::uuid;
  v_hotel1_id uuid := 'd0000000-0000-4000-1000-000000000003'::uuid;
  v_pg1_id uuid := 'd0000000-0000-4000-1000-000000000004'::uuid;

  -- Test slots
  v_fh1_slot_morn uuid := 'd0000000-0000-4000-2000-000000000001'::uuid;
  v_fh1_slot_eve uuid := 'd0000000-0000-4000-2000-000000000002'::uuid;
  v_hotel1_slot_dlx uuid := 'd0000000-0000-4000-2000-000000000003'::uuid;
  v_pg1_slot_sgl uuid := 'd0000000-0000-4000-2000-000000000004'::uuid;

  -- Test users lookup
  v_cust_id uuid;
  v_owner_id uuid;

  -- Test booking & hold UUIDs
  v_hold1_id uuid := 'd0000000-0000-4000-3000-000000000001'::uuid;
  v_book1_id uuid := 'd0000000-0000-4000-4000-000000000001'::uuid;
  v_book2_id uuid := 'd0000000-0000-4000-4000-000000000002'::uuid;
  v_book3_id uuid := 'd0000000-0000-4000-4000-000000000003'::uuid;
begin
  -- Resolve Category UUIDs
  select id into v_cat_fh from public.venue_categories where slug = 'function_hall';
  select id into v_cat_hotel from public.venue_categories where slug = 'hotel_stay';
  select id into v_cat_pg from public.venue_categories where slug = 'pg_coliving';

  -- Resolve User IDs
  select id into v_cust_id from auth.users where email = 'customer.dev@bookmyspace.app';
  select id into v_owner_id from auth.users where email = 'owner.dev@bookmyspace.app';

  -- Create Org if not exists and org_id available
  if not exists (select 1 from public.organizations where id = v_org_id) then
    if v_owner_id is not null then
      insert into public.organizations (id, owner_user_id, org_type, name, commission_rate)
      values (v_org_id, v_owner_id, 'venue_owner', 'DEV Test Venues & Stays Org', 10.00)
      on conflict (id) do nothing;
    elsif exists (select 1 from public.organizations) then
      select id into v_org_id from public.organizations limit 1;
    end if;
  end if;

  -- Insert Venues if Org exists
  if exists (select 1 from public.organizations where id = v_org_id) then

    -- ---------------------------------------------------------
    -- VENUE 1: Function Hall (Approved / Published)
    -- ---------------------------------------------------------
    insert into public.venues (
      id, org_id, category_id, name, slug, description, address_line1, city, state, postal_code,
      country, latitude, longitude, capacity, pricing_base_amount, tax_rate, parking_capacity,
      food_options, rules, is_verified, is_active, avg_rating, rating_count
    ) values (
      v_fh1_id, v_org_id, v_cat_fh,
      'Royal Crown Function Hall (DEV Test)', 'royal-crown-function-hall-dev',
      'Grand wedding and event convention hall with central AC, stage lighting, and full power backup.',
      '12 Jubilee Hills Main Rd', 'Hyderabad', 'Telangana', '500033', 'IN',
      17.4325, 78.4071, 800, 45000.00, 18.00, 100,
      'In-house catering and external allowed',
      'No loud music after 10 PM. Firecrackers strictly prohibited inside hall.',
      true, true, 4.8, 42
    ) on conflict (id) do nothing;

    -- ---------------------------------------------------------
    -- VENUE 2: Function Hall (Pending Approval)
    -- ---------------------------------------------------------
    insert into public.venues (
      id, org_id, category_id, name, slug, description, address_line1, city, state, postal_code,
      country, latitude, longitude, capacity, pricing_base_amount, tax_rate, parking_capacity,
      food_options, rules, is_verified, is_active, avg_rating, rating_count
    ) values (
      v_fh2_id, v_org_id, v_cat_fh,
      'Grand Horizon Convention (Pending DEV)', 'grand-horizon-convention-dev',
      'Newly listed large scale convention space awaiting admin verification.',
      '88 Gachibowli Ring Rd', 'Hyderabad', 'Telangana', '500032', 'IN',
      17.4401, 78.3489, 1200, 60000.00, 18.00, 150,
      'Approved vendors list provided upon booking',
      'Standard venue safety guidelines apply.',
      false, true, 0.0, 0
    ) on conflict (id) do nothing;

    -- ---------------------------------------------------------
    -- VENUE 3: Hotel / Stay (Approved Property)
    -- ---------------------------------------------------------
    insert into public.venues (
      id, org_id, category_id, name, slug, description, address_line1, city, state, postal_code,
      country, latitude, longitude, capacity, pricing_base_amount, tax_rate, parking_capacity,
      food_options, rules, is_verified, is_active, avg_rating, rating_count
    ) values (
      v_hotel1_id, v_org_id, v_cat_hotel,
      'Monarch Boutique Hotel & Suites (DEV)', 'monarch-boutique-hotel-dev',
      'Premium hotel stay with luxury rooms, rooftop restaurant, complimentary breakfast, and WiFi.',
      '45 Indiranagar 100ft Rd', 'Bengaluru', 'Karnataka', '560038', 'IN',
      12.9784, 77.6408, 150, 3500.00, 12.00, 30,
      'Complimentary buffet breakfast, 24/7 room service',
      'Government ID required at check-in. Standard 12:00 PM check-in / 11:00 AM check-out.',
      true, true, 4.6, 88
    ) on conflict (id) do nothing;

    -- ---------------------------------------------------------
    -- VENUE 4: PG / Co-Living (Approved PG)
    -- ---------------------------------------------------------
    insert into public.venues (
      id, org_id, category_id, name, slug, description, address_line1, city, state, postal_code,
      country, latitude, longitude, capacity, pricing_base_amount, tax_rate, parking_capacity,
      food_options, rules, is_verified, is_active, avg_rating, rating_count
    ) values (
      v_pg1_id, v_org_id, v_cat_pg,
      'UrbanNest Luxury PG & Co-Living (DEV)', 'urbannest-pg-coliving-dev',
      'Modern unisex co-living with dedicated single & twin sharing rooms, high-speed WiFi, laundry, and meals.',
      '102 HSR Layout Sector 1', 'Bengaluru', 'Karnataka', '560102', 'IN',
      12.9121, 77.6445, 60, 12000.00, 0.00, 20,
      '3 meals daily provided (North & South Indian menu)',
      'Unisex building with dedicated gender floors. Security deposit equal to 1 month rent.',
      true, true, 4.7, 31
    ) on conflict (id) do nothing;

    -- ---------------------------------------------------------
    -- TIME SLOTS / UNITS / PACKAGES
    -- ---------------------------------------------------------
    -- Function Hall 1 Slots
    insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active) values
      (v_fh1_slot_morn, v_fh1_id, 'Morning Event Slot', '08:00', '14:00', 25000.00, true),
      (v_fh1_slot_eve, v_fh1_id, 'Evening Reception Slot', '16:00', '23:30', 35000.00, true)
    on conflict (id) do nothing;

    -- Hotel 1 Room Slots
    insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active) values
      (v_hotel1_slot_dlx, v_hotel1_id, 'Deluxe Suite Room (Per Night)', '12:00', '11:00', 3500.00, true)
    on conflict (id) do nothing;

    -- PG 1 Unit Slots
    insert into public.time_slots (id, venue_id, label, start_time, end_time, price_amount, is_active) values
      (v_pg1_slot_sgl, v_pg1_id, 'Single Private Room (Monthly)', '00:00', '23:59', 12000.00, true)
    on conflict (id) do nothing;

    -- ---------------------------------------------------------
    -- FACILITIES & IMAGES & OPERATING HOURS
    -- ---------------------------------------------------------
    -- Facilities
    insert into public.venue_facilities (venue_id, facility) values
      (v_fh1_id, 'Air Conditioning'), (v_fh1_id, 'Stage & Lighting'), (v_fh1_id, 'Valet Parking'), (v_fh1_id, 'Power Backup'),
      (v_hotel1_id, 'High-Speed WiFi'), (v_hotel1_id, 'Rooftop Restaurant'), (v_hotel1_id, '24/7 Front Desk'),
      (v_pg1_id, 'Daily Housekeeping'), (v_pg1_id, 'Washing Machines'), (v_pg1_id, 'Biometric Access')
    on conflict (venue_id, facility) do nothing;

    -- Operating hours (All days 0-6)
    insert into public.venue_operating_hours (venue_id, day_of_week, opens_at, closes_at)
    select v_id, d, '06:00'::time, '23:30'::time
    from unnest(array[v_fh1_id, v_fh2_id, v_hotel1_id, v_pg1_id]) as v_id,
         generate_series(0, 6) as d
    on conflict (venue_id, day_of_week) do nothing;

    -- Images
    insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order) values
      (v_fh1_id, 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3', 'Royal Crown Main Hall', true, 0),
      (v_hotel1_id, 'https://images.unsplash.com/photo-1566073771259-6a8506099945', 'Monarch Hotel Exterior', true, 0),
      (v_pg1_id, 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5', 'UrbanNest PG Room', true, 0)
    on conflict do nothing;

    -- ---------------------------------------------------------
    -- TEST SCENARIOS (Holds, Bookings, Payments)
    -- Linked when test customer user exists
    -- ---------------------------------------------------------
    if v_cust_id is not null then

      -- Scenario A: Active Slot Hold (Function Hall 1)
      insert into public.booking_holds (
        id, idempotency_key, venue_id, slot_id, book_date, user_id, price_amount, expires_at, status
      ) values (
        v_hold1_id, 'd0000000-0000-4000-c000-000000000001'::uuid,
        v_fh1_id, v_fh1_slot_eve, current_date + interval '10 days', v_cust_id, 35000.00,
        now() + interval '10 minutes', 'active'
      ) on conflict (id) do nothing;

      -- Scenario B: Confirmed Online Booking + Synthetic Razorpay Payment
      insert into public.bookings (
        id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
        status, quantity, amount, currency, tax_amount, discount_amount, total_amount,
        metadata, confirmed_at
      ) values (
        v_book1_id, 'BMS-DEV-001', v_cust_id, v_fh1_id, v_fh1_slot_morn,
        current_date + interval '15 days', '08:00', '14:00',
        'confirmed', 1, 25000.00, 'INR', 4500.00, 0.00, 29500.00,
        '{"synthetic_fixture": true, "environment": "DEV", "note": "Test confirmed online booking"}'::jsonb,
        now()
      ) on conflict (id) do nothing;

      insert into public.payments (
        booking_id, user_id, provider, provider_order_id, provider_payment_id,
        amount, currency, status, method, metadata
      ) select
        v_book1_id, v_cust_id, 'razorpay', 'order_dev_test_001', 'pay_dev_test_001',
        29500.00, 'INR', 'captured', 'upi',
        '{"synthetic_fixture": true, "is_test_mode": true}'::jsonb
      where not exists (select 1 from public.payments where provider_order_id = 'order_dev_test_001');

      -- Scenario C: Owner Offline Booking
      insert into public.bookings (
        id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
        status, quantity, amount, currency, tax_amount, discount_amount, total_amount,
        metadata, confirmed_at
      ) values (
        v_book2_id, 'BMS-DEV-002', v_cust_id, v_fh1_id, v_fh1_slot_eve,
        current_date + interval '20 days', '16:00', '23:30',
        'confirmed', 1, 35000.00, 'INR', 6300.00, 0.00, 41300.00,
        '{"synthetic_fixture": true, "booking_type": "offline_owner", "payment_method": "cash_at_venue"}'::jsonb,
        now()
      ) on conflict (id) do nothing;

      -- Scenario D: Confirmed Hotel Room Stay
      insert into public.bookings (
        id, booking_ref, user_id, venue_id, slot_id, book_date, start_time, end_time,
        status, quantity, amount, currency, tax_amount, discount_amount, total_amount,
        metadata, confirmed_at
      ) values (
        v_book3_id, 'BMS-DEV-003', v_cust_id, v_hotel1_id, v_hotel1_slot_dlx,
        current_date + interval '5 days', '12:00', '11:00',
        'confirmed', 1, 3500.00, 'INR', 420.00, 0.00, 3920.00,
        '{"synthetic_fixture": true, "stay_type": "hotel_room", "guest_count": 2}'::jsonb,
        now()
      ) on conflict (id) do nothing;

    end if;

  end if;
end $$;

-- ------------------------------------------------------------
-- 4. DEV COUPONS
-- ------------------------------------------------------------
insert into public.coupons (code, description, discount_type, discount_value, max_discount_amount, min_booking_amount, ends_at)
values
  ('DEV1000', 'DEV Test coupon - Flat ₹1,000 off', 'fixed', 1000.00, NULL, 5000, now() + interval '1 year'),
  ('DEV20OFF', 'DEV Test coupon - 20% off', 'percentage', 20.00, 3000, 2000, now() + interval '1 year')
on conflict (code) do nothing;

-- ============================================================
-- Phase 3 — Owner + Admin hardening
-- 1. Owner venue content RPCs (address, contact, amenities, images)
-- 2. Owner + admin audit logging with tightened audit RLS
-- 3. Owner-verified field guards on owner RPCs (server-side)
-- 4. RBAC hardening (remove anon/authenticated privileged surface)
-- 5. venue-images storage bucket for owner gallery uploads
-- ============================================================

-- ------------------------------------------------------------
-- AUDIT: shared write helper for authenticated actors
-- (self-identity only: actor_id always auth.uid())
-- ------------------------------------------------------------
create or replace function public.write_owner_audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid default null,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(),
    p_action,
    p_entity_type,
    p_entity_id,
    coalesce(p_details, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.write_owner_audit(text, text, uuid, jsonb) from public, anon;
grant execute on function public.write_owner_audit(text, text, uuid, jsonb)
  to authenticated, service_role;

-- Admin audit helper must require an actual admin (was callable by any
-- authenticated user, allowing forged entries).
create or replace function public.write_admin_content_audit(
  p_action text,
  p_entity_type text,
  p_entity_id uuid default null,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, details)
  values (
    auth.uid(),
    p_action,
    p_entity_type,
    p_entity_id,
    coalesce(p_details, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.write_admin_content_audit(text, text, uuid, jsonb) from public, anon;
grant execute on function public.write_admin_content_audit(text, text, uuid, jsonb)
  to authenticated, service_role;

-- ------------------------------------------------------------
-- AUDIT RLS: reads only for administrators; inserts only for the
-- caller's own actor_id (function-mediated writes bypass RLS).
-- Previously any authenticated user could insert and every venue
-- owner could read the full audit log.
-- ------------------------------------------------------------
drop policy if exists audit_insert_any_auth on public.audit_logs;
drop policy if exists audit_admin_insert on public.audit_logs;
drop policy if exists audit_admin_read on public.audit_logs;
drop policy if exists audit_read_admin on public.audit_logs;
-- Make the migration re-runnable (idempotent policy recreation).
drop policy if exists audit_logs_insert_own on public.audit_logs;
drop policy if exists audit_logs_admin_read on public.audit_logs;

create policy audit_logs_insert_own on public.audit_logs
  for insert to authenticated
  with check (actor_id = auth.uid());

create policy audit_logs_admin_read on public.audit_logs
  for select to authenticated
  using (public.is_admin_user());

-- ------------------------------------------------------------
-- OWNER-VERIFIED FIELD GUARD (owner-side, mirrors admin lock)
-- ------------------------------------------------------------
create or replace function public.owner_venue_field_locked(
  p_venue public.venues,
  p_field text
)
returns boolean
language sql
stable
as $$
  select
    coalesce(p_venue.owner_verified, false)
    or (
      jsonb_typeof(coalesce(p_venue.owner_verified_fields, '[]'::jsonb)) = 'array'
      and coalesce(p_venue.owner_verified_fields, '[]'::jsonb) ? p_field
    );
$$;

-- ------------------------------------------------------------
-- OWNER VENUE CRUD (extended content fields)
-- ------------------------------------------------------------
drop function if exists public.create_owner_venue(
  text, uuid, text, text, text, double precision, double precision, integer, numeric
);

create or replace function public.create_owner_venue(
  p_name text,
  p_category_id uuid,
  p_description text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_capacity integer,
  p_pricing_base_amount numeric,
  p_address_line1 text default null,
  p_address_line2 text default null,
  p_postal_code text default null,
  p_phone text default null,
  p_website text default null,
  p_amenities text[] default null,
  p_image_urls text[] default null
)
returns public.venues
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_org_id uuid;
  v_venue public.venues;
  v_url text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if nullif(trim(p_name), '') is null then
    raise exception 'invalid_name';
  end if;
  if p_category_id is null then
    raise exception 'invalid_category';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid_coordinates';
  end if;

  select id into v_org_id
  from public.organizations
  where owner_user_id = auth.uid() and deleted_at is null
  limit 1;

  if v_org_id is null then
    raise exception 'owner_org_not_found';
  end if;

  insert into public.venues (
    org_id, category_id, name, description, city, state,
    address_line1, address_line2, postal_code, phone, website,
    latitude, longitude, capacity, pricing_base_amount, slug
  ) values (
    v_org_id, p_category_id, trim(p_name), p_description, p_city, p_state,
    p_address_line1, p_address_line2, p_postal_code,
    public.normalize_venue_phone(p_phone), p_website,
    p_latitude, p_longitude, p_capacity, p_pricing_base_amount,
    lower(regexp_replace(p_name, '[^a-zA-Z0-9]+', '-', 'g'))
  ) returning * into v_venue;

  if p_amenities is not null then
    foreach v_url in array p_amenities
    loop
      if nullif(trim(v_url), '') is not null then
        insert into public.venue_facilities (venue_id, facility, is_available)
        values (v_venue.id, trim(v_url), true)
        on conflict (venue_id, facility) do update set is_available = true;
      end if;
    end loop;
  end if;

  if p_image_urls is not null then
    foreach v_url in array p_image_urls
    loop
      if nullif(trim(v_url), '') is not null
         and v_url ~* '^https?://' then
        insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
        values (v_venue.id, trim(v_url), v_venue.name, false, 0);
      end if;
    end loop;
    update public.venue_images
    set is_cover = true
    where id = (
      select id from public.venue_images
      where venue_id = v_venue.id
      order by created_at limit 1
    );
  end if;

  perform public.write_owner_audit(
    'owner_create_venue',
    'venue',
    v_venue.id,
    jsonb_build_object('name', v_venue.name, 'category_id', p_category_id, 'pricing_base_amount', p_pricing_base_amount)
  );

  return v_venue;
end;
$$;

revoke all on function public.create_owner_venue(
  text, uuid, text, text, text, double precision, double precision, integer, numeric,
  text, text, text, text, text, text[], text[]
) from public, anon;
grant execute on function public.create_owner_venue(
  text, uuid, text, text, text, double precision, double precision, integer, numeric,
  text, text, text, text, text, text[], text[]
) to authenticated;

drop function if exists public.update_owner_venue(
  uuid, text, uuid, text, text, text, double precision, double precision, integer, numeric, boolean
);

create or replace function public.update_owner_venue(
  p_venue_id uuid,
  p_name text default null,
  p_category_id uuid default null,
  p_description text default null,
  p_city text default null,
  p_state text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_capacity integer default null,
  p_pricing_base_amount numeric default null,
  p_is_active boolean default null,
  p_address_line1 text default null,
  p_address_line2 text default null,
  p_postal_code text default null,
  p_phone text default null,
  p_website text default null,
  p_amenities text[] default null,
  p_image_urls text[] default null
)
returns public.venues
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue public.venues;
  v_locked text[] := '{}';
  v_url text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid()
    and v.deleted_at is null;

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  if p_name is not null then
    if public.owner_venue_field_locked(v_venue, 'name') then
      v_locked := array_append(v_locked, 'name');
    elsif nullif(trim(p_name), '') is null then
      raise exception 'invalid_name';
    else
      v_venue.name := trim(p_name);
    end if;
  end if;

  if p_category_id is not null then
    if public.owner_venue_field_locked(v_venue, 'category_id') then
      v_locked := array_append(v_locked, 'category_id');
    else
      v_venue.category_id := p_category_id;
    end if;
  end if;

  if p_description is not null then
    v_venue.description := p_description;
  end if;

  if p_city is not null then
    if public.owner_venue_field_locked(v_venue, 'city') then
      v_locked := array_append(v_locked, 'city');
    else
      v_venue.city := p_city;
    end if;
  end if;

  if p_state is not null then
    if public.owner_venue_field_locked(v_venue, 'state') then
      v_locked := array_append(v_locked, 'state');
    else
      v_venue.state := p_state;
    end if;
  end if;

  if p_latitude is not null or p_longitude is not null then
    if public.owner_venue_field_locked(v_venue, 'latitude')
       or public.owner_venue_field_locked(v_venue, 'longitude') then
      v_locked := array_append(v_locked, 'coordinates');
    else
      v_venue.latitude := coalesce(p_latitude, v_venue.latitude);
      v_venue.longitude := coalesce(p_longitude, v_venue.longitude);
      if v_venue.latitude < -90 or v_venue.latitude > 90
         or v_venue.longitude < -180 or v_venue.longitude > 180 then
        raise exception 'invalid_coordinates';
      end if;
    end if;
  end if;

  if p_capacity is not null then
    if p_capacity <= 0 then
      raise exception 'invalid_capacity';
    end if;
    v_venue.capacity := p_capacity;
  end if;

  if p_pricing_base_amount is not null then
    if p_pricing_base_amount < 0 then
      raise exception 'invalid_pricing_base_amount';
    end if;
    v_venue.pricing_base_amount := p_pricing_base_amount;
  end if;

  if p_address_line1 is not null then
    if public.owner_venue_field_locked(v_venue, 'address_line1') then
      v_locked := array_append(v_locked, 'address_line1');
    else
      v_venue.address_line1 := nullif(trim(p_address_line1), '');
    end if;
  end if;

  if p_address_line2 is not null then
    if public.owner_venue_field_locked(v_venue, 'address_line2') then
      v_locked := array_append(v_locked, 'address_line2');
    else
      v_venue.address_line2 := nullif(trim(p_address_line2), '');
    end if;
  end if;

  if p_postal_code is not null then
    if public.owner_venue_field_locked(v_venue, 'postal_code') then
      v_locked := array_append(v_locked, 'postal_code');
    else
      v_venue.postal_code := nullif(trim(p_postal_code), '');
    end if;
  end if;

  if p_phone is not null then
    if public.owner_venue_field_locked(v_venue, 'phone') then
      v_locked := array_append(v_locked, 'phone');
    else
      v_venue.phone := public.normalize_venue_phone(p_phone);
    end if;
  end if;

  if p_website is not null then
    if public.owner_venue_field_locked(v_venue, 'website') then
      v_locked := array_append(v_locked, 'website');
    else
      v_venue.website := nullif(trim(p_website), '');
    end if;
  end if;

  if p_is_active is not null then
    v_venue.is_active := p_is_active;
  end if;

  if array_length(v_locked, 1) is not null then
    raise exception 'owner_verified_locked:%', array_to_string(v_locked, ',');
  end if;

  update public.venues v
  set
    name = v_venue.name,
    category_id = v_venue.category_id,
    description = v_venue.description,
    city = v_venue.city,
    state = v_venue.state,
    address_line1 = v_venue.address_line1,
    address_line2 = v_venue.address_line2,
    postal_code = v_venue.postal_code,
    phone = v_venue.phone,
    website = v_venue.website,
    latitude = v_venue.latitude,
    longitude = v_venue.longitude,
    capacity = v_venue.capacity,
    pricing_base_amount = v_venue.pricing_base_amount,
    is_active = v_venue.is_active,
    slug = case when p_name is not null
           then lower(regexp_replace(v_venue.name, '[^a-zA-Z0-9]+', '-', 'g'))
           else v.slug end,
    updated_at = now()
  where v.id = p_venue_id
  returning v.* into v_venue;

  if p_amenities is not null then
    delete from public.venue_facilities where venue_id = p_venue_id;
    foreach v_url in array p_amenities
    loop
      if nullif(trim(v_url), '') is not null then
        insert into public.venue_facilities (venue_id, facility, is_available)
        values (p_venue_id, trim(v_url), true)
        on conflict (venue_id, facility) do update set is_available = true;
      end if;
    end loop;
  end if;

  if p_image_urls is not null then
    delete from public.venue_images where venue_id = p_venue_id;
    foreach v_url in array p_image_urls
    loop
      if nullif(trim(v_url), '') is not null and v_url ~* '^https?://' then
        insert into public.venue_images (venue_id, url, alt_text, is_cover, sort_order)
        values (p_venue_id, trim(v_url), v_venue.name, false, 0);
      end if;
    end loop;
    update public.venue_images
    set is_cover = true
    where id = (
      select id from public.venue_images
      where venue_id = p_venue_id
      order by created_at limit 1
    );
  end if;

  perform public.write_owner_audit(
    'owner_update_venue',
    'venue',
    p_venue_id,
    jsonb_build_object(
      'name', v_venue.name,
      'pricing_base_amount', v_venue.pricing_base_amount,
      'is_active', v_venue.is_active,
      'is_owner_verified', coalesce(v_venue.owner_verified, false)
    )
  );

  return v_venue;
end;
$$;

revoke all on function public.update_owner_venue(
  uuid, text, uuid, text, text, text, double precision, double precision, integer, numeric, boolean,
  text, text, text, text, text, text[], text[]
) from public, anon;
grant execute on function public.update_owner_venue(
  uuid, text, uuid, text, text, text, double precision, double precision, integer, numeric, boolean,
  text, text, text, text, text, text[], text[]
) to authenticated;

-- Owner venue detail (venue + gallery + facilities) for the edit screen.
create or replace function public.get_owner_venue_detail(p_venue_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue public.venues;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid()
    and v.deleted_at is null;

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  return jsonb_build_object(
    -- Flatten the venue row so client models parse it directly
    -- (venue_categories nested as a sibling, matching Venue.fromJson).
    'venue', to_jsonb(v_venue) || jsonb_build_object(
      'venue_categories',
      (select to_jsonb(vc) from public.venue_categories vc where vc.id = v_venue.category_id)
    ),
    'images', coalesce(
      (select jsonb_agg(to_jsonb(vi) order by vi.is_cover desc, vi.sort_order, vi.created_at)
       from public.venue_images vi where vi.venue_id = v_venue.id),
      '[]'::jsonb
    ),
    'facilities', coalesce(
      (select jsonb_agg(to_jsonb(vf) order by vf.facility)
       from public.venue_facilities vf where vf.venue_id = v_venue.id),
      '[]'::jsonb
    )
  );
end;
$$;

revoke all on function public.get_owner_venue_detail(uuid) from public, anon;
grant execute on function public.get_owner_venue_detail(uuid) to authenticated;

-- ------------------------------------------------------------
-- OWNER IMAGE / AMENITY RPCs (mirror admin, owner-gated)
-- ------------------------------------------------------------
create or replace function public.owner_replace_venue_images(
  p_venue_id uuid,
  p_images jsonb
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
  v_elem jsonb;
  v_idx integer := 0;
  v_url text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not exists (
    select 1 from public.venues v
    join public.organizations o on o.id = v.org_id
    where v.id = p_venue_id and o.owner_user_id = auth.uid() and v.deleted_at is null
  ) then
    raise exception 'venue_not_found_or_not_owner';
  end if;
  if p_images is null or jsonb_typeof(p_images) <> 'array' then
    raise exception 'images_array_required';
  end if;

  delete from public.venue_images where venue_id = p_venue_id;

  for v_elem in select * from jsonb_array_elements(p_images)
  loop
    v_url := nullif(trim(v_elem->>'url'), '');
    if v_url is null then
      raise exception 'invalid_image_url';
    end if;
    if v_url !~* '^https?://' then
      raise exception 'invalid_image_url_scheme';
    end if;
    insert into public.venue_images (
      venue_id, url, thumbnail_url, alt_text, is_cover, sort_order
    ) values (
      p_venue_id,
      v_url,
      nullif(trim(v_elem->>'thumbnail_url'), ''),
      nullif(trim(v_elem->>'alt_text'), ''),
      coalesce((v_elem->>'is_cover')::boolean, v_idx = 0),
      coalesce((v_elem->>'sort_order')::integer, v_idx)
    );
    v_idx := v_idx + 1;
    v_count := v_count + 1;
  end loop;

  perform public.write_owner_audit(
    'owner_replace_venue_images',
    'venue',
    p_venue_id,
    jsonb_build_object('image_count', v_count)
  );

  return v_count;
end;
$$;

revoke all on function public.owner_replace_venue_images(uuid, jsonb) from public, anon;
grant execute on function public.owner_replace_venue_images(uuid, jsonb) to authenticated;

create or replace function public.owner_set_venue_amenities(
  p_venue_id uuid,
  p_amenities text[]
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item text;
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if not exists (
    select 1 from public.venues v
    join public.organizations o on o.id = v.org_id
    where v.id = p_venue_id and o.owner_user_id = auth.uid() and v.deleted_at is null
  ) then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  delete from public.venue_facilities where venue_id = p_venue_id;

  if p_amenities is not null then
    foreach v_item in array p_amenities
    loop
      if nullif(trim(v_item), '') is null then
        continue;
      end if;
      insert into public.venue_facilities (venue_id, facility, is_available)
      values (p_venue_id, trim(v_item), true)
      on conflict (venue_id, facility) do update set is_available = true;
      v_count := v_count + 1;
    end loop;
  end if;

  perform public.write_owner_audit(
    'owner_set_venue_amenities',
    'venue',
    p_venue_id,
    jsonb_build_object('count', v_count)
  );

  return v_count;
end;
$$;

revoke all on function public.owner_set_venue_amenities(uuid, text[]) from public, anon;
grant execute on function public.owner_set_venue_amenities(uuid, text[]) to authenticated;

-- ------------------------------------------------------------
-- OWNER DELETE VENUE: audit
-- ------------------------------------------------------------
create or replace function public.delete_owner_venue(p_venue_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue public.venues;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id
    and o.owner_user_id = auth.uid()
    and v.deleted_at is null;

  if v_venue is null then
    raise exception 'venue_not_found_or_not_owner';
  end if;

  update public.venues
  set deleted_at = now(), is_active = false, updated_at = now()
  where id = p_venue_id;

  perform public.write_owner_audit(
    'owner_delete_venue',
    'venue',
    p_venue_id,
    jsonb_build_object('name', v_venue.name)
  );
end;
$$;

revoke all on function public.delete_owner_venue(uuid) from public, anon;
grant execute on function public.delete_owner_venue(uuid) to authenticated;

-- ------------------------------------------------------------
-- OWNER BOOKING DECISIONS / OFFLINE BOOKINGS: audit
-- ------------------------------------------------------------
create or replace function public.owner_decide_booking(p_booking_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select b.venue_id into v_venue_id
  from public.bookings b
  join public.venues v on v.id = b.venue_id
  join public.organizations o on o.id = v.org_id
  where b.id = p_booking_id
    and o.owner_user_id = auth.uid();

  update public.bookings b set
    status = case when p_accept then 'confirmed'::public.booking_status else 'cancelled'::public.booking_status end,
    confirmed_at = case when p_accept then now() else null end,
    cancelled_at = case when p_accept then null else now() end
  where b.id = p_booking_id
    and b.status = 'pending'
    and exists(
      select 1 from public.venues v join public.organizations o on o.id = v.org_id
      where v.id = b.venue_id and o.owner_user_id = auth.uid()
    );

  if not found then
    raise exception 'booking not found or not permitted';
  end if;

  perform public.write_owner_audit(
    case when p_accept then 'owner_approve_booking' else 'owner_reject_booking' end,
    'booking',
    p_booking_id,
    jsonb_build_object('venue_id', v_venue_id, 'accepted', p_accept)
  );
end;
$$;

revoke all on function public.owner_decide_booking(uuid, boolean) from public, anon;
grant execute on function public.owner_decide_booking(uuid, boolean) to authenticated;

create or replace function public.create_offline_booking(
  p_venue_id uuid, p_slot_id uuid, p_book_date date, p_customer_name text, p_customer_phone text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_slot public.time_slots; v_id uuid; v_amount numeric; v_tax numeric;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  perform pg_advisory_xact_lock(hashtext(p_venue_id::text || p_book_date::text));
  select s.* into v_slot from public.time_slots s join public.venues v on v.id=s.venue_id
  join public.organizations o on o.id=v.org_id
  where s.id=p_slot_id and s.venue_id=p_venue_id and s.is_active and o.owner_user_id=auth.uid();
  if not found then
    raise exception 'slot not found or not permitted';
  end if;
  select v_slot.price_amount,round(v_slot.price_amount*v.tax_rate/100,2) into v_amount,v_tax
  from public.venues v where v.id=p_venue_id;
  insert into public.bookings(booking_ref,user_id,venue_id,slot_id,book_date,start_time,end_time,status,amount,tax_amount,total_amount,metadata,confirmed_at)
  values('OFF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)),auth.uid(),p_venue_id,p_slot_id,p_book_date,
    v_slot.start_time,v_slot.end_time,'confirmed',v_amount,v_tax,v_amount+v_tax,
    jsonb_build_object('source','offline','customer_name',p_customer_name,'customer_phone',p_customer_phone),now())
  returning id into v_id;

  perform public.write_owner_audit(
    'owner_offline_booking',
    'booking',
    v_id,
    jsonb_build_object('venue_id', p_venue_id, 'slot_id', p_slot_id, 'book_date', p_book_date)
  );

  return v_id;
end;
$$;

revoke all on function public.create_offline_booking(uuid,uuid,date,text,text) from public, anon;
grant execute on function public.create_offline_booking(uuid,uuid,date,text,text) to authenticated;

-- ------------------------------------------------------------
-- OWNER PROFILE SAVE: audit
-- ------------------------------------------------------------
create or replace function public.save_owner_profile(
  p_name text,
  p_phone text default null,
  p_whatsapp text default null,
  p_business_name text default null,
  p_address text default null,
  p_city text default null,
  p_state text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_photo_url text default null
) returns jsonb language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_uid uuid:=auth.uid(); v_email text; v_org uuid;
begin
  if v_uid is null then raise exception 'authentication required'; end if;
  select email into v_email from auth.users where id=v_uid;
  if nullif(trim(p_name),'') is null then raise exception 'name required'; end if;
  insert into public.owner_profiles(user_id,email,name,phone,whatsapp,photo_url)
  values(v_uid,v_email,trim(p_name),p_phone,p_whatsapp,p_photo_url)
  on conflict(user_id) do update set name=excluded.name,phone=excluded.phone,
    whatsapp=excluded.whatsapp,photo_url=excluded.photo_url,updated_at=now();
  insert into public.profiles(id,full_name,phone,email,avatar_url)
  values(v_uid,trim(p_name),p_phone,v_email,p_photo_url)
  on conflict(id) do update set full_name=excluded.full_name,phone=excluded.phone,
    avatar_url=excluded.avatar_url,updated_at=now();
  insert into public.user_roles(user_id,role) values(v_uid,'venue_owner')
  on conflict(user_id,role) do update set revoked_at=null;
  select id into v_org from public.organizations where owner_user_id=v_uid and deleted_at is null limit 1;
  if v_org is null then
    insert into public.organizations(owner_user_id,org_type,name,address_line1,city,state,latitude,longitude)
    values(v_uid,'venue_owner',coalesce(nullif(trim(p_business_name),''),trim(p_name)),p_address,p_city,p_state,p_latitude,p_longitude)
    returning id into v_org;
  else
    update public.organizations set
      name=coalesce(nullif(trim(p_business_name),''),name),address_line1=p_address,
      city=p_city,state=p_state,latitude=p_latitude,longitude=p_longitude,updated_at=now()
    where id=v_org;
  end if;
  update public.profiles set default_org_id=v_org where id=v_uid;

  perform public.write_owner_audit(
    'owner_profile_update',
    'owner_profile',
    v_uid,
    jsonb_build_object('name', trim(p_name), 'phone', p_phone, 'business_name', p_business_name)
  );

  return public.get_owner_profile();
end; $$;

revoke all on function public.save_owner_profile(
  text,text,text,text,text,text,text,double precision,double precision,text
) from public, anon;
grant execute on function public.save_owner_profile(
  text,text,text,text,text,text,text,double precision,double precision,text
) to authenticated;

-- ------------------------------------------------------------
-- VENUE IMAGES STORAGE BUCKET (owner gallery upload)
-- ------------------------------------------------------------
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'venue-images', 'venue-images', true, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists venue_images_upload on storage.objects;
create policy venue_images_upload on storage.objects
  for insert to authenticated
  with check (bucket_id = 'venue-images');

drop policy if exists venue_images_public_read on storage.objects;
create policy venue_images_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'venue-images');

-- One command per policy (Postgres does not allow 'for update, delete').
drop policy if exists venue_images_owner_modify on storage.objects;
create policy venue_images_owner_modify on storage.objects
  for update to authenticated
  using (bucket_id = 'venue-images');

drop policy if exists venue_images_owner_delete on storage.objects;
create policy venue_images_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'venue-images');

-- ------------------------------------------------------------
-- RBAC HARDENING
-- ------------------------------------------------------------
-- get_owner_user_id is an owner-identity probe; keep it out of anon.
revoke all on function public.get_owner_user_id() from anon;

-- staged_venues / import_jobs views expose import PII to every
-- authenticated user (views bypass engine-table RLS). The Flutter
-- admin flows read the engine tables (admin-only RLS) directly.
revoke select on public.staged_venues from authenticated;
revoke select on public.import_jobs from authenticated;

-- Webhook idempotency registry: service_role only.
revoke all on function public.register_webhook_event(text, text, text, jsonb) from public, anon;
grant execute on function public.register_webhook_event(text, text, text, jsonb) to service_role;

-- Cron/edge-function maintenance RPCs: no anon/public surface.
revoke all on function public.expire_stale_holds() from public, anon;
grant execute on function public.expire_stale_holds() to service_role;

revoke all on function public.reconcile_stale_payments(integer) from public, anon;
grant execute on function public.reconcile_stale_payments(integer) to service_role;

revoke all on function public.acquire_booking_hold(
  uuid, uuid, date, uuid, uuid, numeric, integer
) from public, anon;
grant execute on function public.acquire_booking_hold(
  uuid, uuid, date, uuid, uuid, numeric, integer
) to service_role;

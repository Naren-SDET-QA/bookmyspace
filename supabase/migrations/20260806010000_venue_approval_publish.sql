-- ============================================================
-- BookMySpace — Venue approval / publish gate (Function Hall vertical)
--
-- PROBLEM
--   Owner-created venues (`create_owner_venue`) insert with the table
--   default `is_active=true`, so they are immediately public + bookable.
--   There is no admin approve/reject/publish step and `update_owner_venue`
--   lets the owner flip `is_active` directly — an owner can self-publish
--   without review.
--
-- FIX (reuse `is_active` as the publish flag; forward-only)
--   1. `create_owner_venue` → insert `is_active=false` (pending review).
--   2. `admin_approve_venue` → admin-only approve/publish (is_active=true,
--      is_verified=true) or reject/unpublish (is_active=false), with audit
--      + owner notification.
--   3. `update_owner_venue` → owners may edit content/pricing but can NO
--      longer flip publish state; `p_is_active` is ignored for owners.
--      Publishing is admin-only.
--   4. Only approved+published+active halls are bookable: `is_active` is
--      already enforced in customer RLS (`venues_public_read`), the venue
--      repository (`.eq('is_active', true)`), and the hold RPC
--      (`acquire_booking_hold_for_current_user` checks `v.is_active`).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Owner-created venues start PENDING (not immediately live)
-- ------------------------------------------------------------
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

  -- is_active=false → submitted for admin review; admin publishes.
  insert into public.venues (
    org_id, category_id, name, description, city, state,
    address_line1, address_line2, postal_code, phone, website,
    latitude, longitude, capacity, pricing_base_amount, slug,
    is_active, is_verified
  ) values (
    v_org_id, p_category_id, trim(p_name), p_description, p_city, p_state,
    p_address_line1, p_address_line2, p_postal_code,
    public.normalize_venue_phone(p_phone), p_website,
    p_latitude, p_longitude, p_capacity, p_pricing_base_amount,
    lower(regexp_replace(p_name, '[^a-zA-Z0-9]+', '-', 'g')),
    false, false
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
    jsonb_build_object('name', v_venue.name, 'category_id', p_category_id,
      'pricing_base_amount', p_pricing_base_amount, 'is_active', false)
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

-- ------------------------------------------------------------
-- 2. ADMIN approve / reject / publish
-- ------------------------------------------------------------
create or replace function public.admin_approve_venue(
  p_venue_id uuid,
  p_approve boolean,
  p_notes text default null
)
returns public.venues
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_venue public.venues;
  v_owner uuid;
  v_prev_active boolean;
  v_prev_verified boolean;
begin
  if not public.is_admin_user() then
    raise exception 'admin_required';
  end if;

  select v.*
    into v_venue
  from public.venues v
  where v.id = p_venue_id and v.deleted_at is null;
  if v_venue is null then
    raise exception 'venue_not_found';
  end if;

  select o.owner_user_id
    into v_owner
  from public.organizations o
  where o.id = v_venue.org_id;

  v_prev_active := v_venue.is_active;
  v_prev_verified := v_venue.is_verified;

  -- Approve → publish + verified. Reject → unpublish (stays listed for owner).
  v_venue.is_active := p_approve;
  v_venue.is_verified := p_approve;
  v_venue.updated_at := now();

  update public.venues
  set is_active = v_venue.is_active,
      is_verified = v_venue.is_verified,
      updated_at = now()
  where id = p_venue_id
  returning * into v_venue;

  perform public.write_admin_content_audit(
    case when p_approve then 'admin_approve_venue' else 'admin_reject_venue' end,
    'venue',
    p_venue_id,
    jsonb_build_object(
      'name', v_venue.name,
      'approved', p_approve,
      'prev_active', v_prev_active,
      'prev_verified', v_prev_verified,
      'notes', p_notes
    )
  );

  -- Notify the venue owner when publish state actually changed.
  if v_owner is not null and v_owner <> auth.uid() then
    insert into public.notifications(user_id, type, title, body, data)
    values (
      v_owner,
      case when p_approve then 'venue_approved' else 'venue_rejected' end,
      case when p_approve then 'Venue approved' else 'Venue not approved' end,
      case when p_approve
           then v_venue.name || ' is now live and bookable.'
           else v_venue.name || ' was not approved.'
      end,
      jsonb_build_object('venue_id', p_venue_id, 'venue_name', v_venue.name,
        'approved', p_approve, 'notes', p_notes)
    );
  end if;

  return v_venue;
end;
$$;

revoke all on function public.admin_approve_venue(uuid, boolean, text) from public, anon;
grant execute on function public.admin_approve_venue(uuid, boolean, text) to authenticated, service_role;

-- ------------------------------------------------------------
-- 3. Owners edit content, but ONLY admins flip publish state
-- ------------------------------------------------------------
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

  -- RBAC: owners can NOT flip publish state. Admin-only via
  -- admin_approve_venue / admin_update_venue_content. `p_is_active` ignored.
  if p_is_active is not null and p_is_active <> v_venue.is_active then
    v_locked := array_append(v_locked, 'is_active');
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

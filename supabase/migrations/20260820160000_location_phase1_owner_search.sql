-- Location Master Phase 1: atomic owner association, descendant search,
-- and strict owner pending-node updates.

create or replace function public.create_owner_venue_with_location(
  p_name text,
  p_category_id uuid,
  p_description text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_capacity integer,
  p_pricing_base_amount numeric,
  p_location_node_id uuid
)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_venue public.venues;
begin
  if not exists (
    select 1 from public.location_nodes
    where id = p_location_node_id
      and status = 'active'
      and approved_at is not null
  ) then
    raise exception 'location_not_found_or_not_approved';
  end if;

  select id into v_org_id
  from public.organizations
  where owner_user_id = auth.uid()
  limit 1;
  if v_org_id is null then raise exception 'owner_org_not_found'; end if;

  insert into public.venues (
    org_id, category_id, name, description, city, state,
    latitude, longitude, capacity, pricing_base_amount, slug, location_node_id
  ) values (
    v_org_id, p_category_id, p_name, p_description, p_city, p_state,
    p_latitude, p_longitude, p_capacity, p_pricing_base_amount,
    lower(replace(p_name, ' ', '-')), p_location_node_id
  ) returning * into v_venue;
  return v_venue;
end;
$$;

create or replace function public.update_owner_venue_with_location(
  p_venue_id uuid,
  p_name text,
  p_category_id uuid,
  p_description text,
  p_city text,
  p_state text,
  p_latitude double precision,
  p_longitude double precision,
  p_capacity integer,
  p_pricing_base_amount numeric,
  p_is_active boolean,
  p_location_node_id uuid
)
returns public.venues
language plpgsql
security definer
set search_path = public
as $$
declare
  v_venue public.venues;
begin
  if not exists (
    select 1 from public.location_nodes
    where id = p_location_node_id
      and status = 'active'
      and approved_at is not null
  ) then
    raise exception 'location_not_found_or_not_approved';
  end if;

  select v.* into v_venue
  from public.venues v
  join public.organizations o on o.id = v.org_id
  where v.id = p_venue_id and o.owner_user_id = auth.uid();
  if v_venue is null then raise exception 'venue_not_found_or_not_owner'; end if;

  update public.venues set
    name = p_name,
    category_id = p_category_id,
    description = p_description,
    city = p_city,
    state = p_state,
    latitude = p_latitude,
    longitude = p_longitude,
    capacity = p_capacity,
    pricing_base_amount = p_pricing_base_amount,
    is_active = p_is_active,
    location_node_id = p_location_node_id,
    slug = lower(replace(p_name, ' ', '-')),
    updated_at = now()
  where id = p_venue_id
  returning * into v_venue;
  return v_venue;
end;
$$;

create or replace function public.get_location_descendants(p_location_id uuid)
returns table(id uuid)
language sql
stable
set search_path = public
as $$
  with recursive descendants as (
    select n.id from public.location_nodes n
    where n.id = p_location_id
      and n.status = 'active'
      and n.approved_at is not null
    union all
    select child.id
    from public.location_nodes child
    join descendants parent on parent.id = child.parent_id
    where child.status = 'active'
      and child.approved_at is not null
  )
  select id from descendants;
$$;

grant execute on function public.get_location_descendants(uuid) to anon, authenticated;
grant execute on function public.create_owner_venue_with_location(text, uuid, text, text, text, double precision, double precision, integer, numeric, uuid) to authenticated;
grant execute on function public.update_owner_venue_with_location(uuid, text, uuid, text, text, text, double precision, double precision, integer, numeric, boolean, uuid) to authenticated;

drop policy if exists location_nodes_owner_pending_update on public.location_nodes;
create policy location_nodes_owner_pending_update on public.location_nodes
for update to authenticated
using (
  created_by = auth.uid() and status = 'pending' and approved_at is null
)
with check (
  created_by = auth.uid() and status = 'pending' and approved_at is null
);

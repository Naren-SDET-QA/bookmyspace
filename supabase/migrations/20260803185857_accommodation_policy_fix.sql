drop policy if exists accommodation_properties_owner_write
  on public.accommodation_properties;

create policy accommodation_properties_owner_insert
  on public.accommodation_properties for insert to authenticated
  with check (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ));
create policy accommodation_properties_owner_update
  on public.accommodation_properties for update to authenticated
  using (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ));
create policy accommodation_properties_owner_delete
  on public.accommodation_properties for delete to authenticated
  using (exists (
    select 1 from public.organizations o
    where o.id = org_id and o.owner_user_id = (select auth.uid())
  ));

create policy accommodation_units_owner_insert
  on public.accommodation_units for insert to authenticated
  with check (exists (
    select 1 from public.accommodation_properties p
    join public.organizations o on o.id = p.org_id
    where p.id = property_id and o.owner_user_id = (select auth.uid())
  ));
create policy accommodation_units_owner_update
  on public.accommodation_units for update to authenticated
  using (exists (
    select 1 from public.accommodation_properties p
    join public.organizations o on o.id = p.org_id
    where p.id = property_id and o.owner_user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.accommodation_properties p
    join public.organizations o on o.id = p.org_id
    where p.id = property_id and o.owner_user_id = (select auth.uid())
  ));
create policy accommodation_units_owner_delete
  on public.accommodation_units for delete to authenticated
  using (exists (
    select 1 from public.accommodation_properties p
    join public.organizations o on o.id = p.org_id
    where p.id = property_id and o.owner_user_id = (select auth.uid())
  ));

grant insert, update, delete on public.accommodation_properties,
  public.accommodation_units to authenticated;

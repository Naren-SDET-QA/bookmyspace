-- Additive Owner/Admin RBAC normalization. Authorization remains based on
-- public.user_roles through has_role(); no JWT user metadata is trusted.

create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.platform_settings enable row level security;

create policy platform_settings_admin_all on public.platform_settings
  for all to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));

create policy organizations_admin_update on public.organizations
  for update to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));

create policy owner_profiles_admin_read on public.owner_profiles
  for select to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'));

create policy venues_admin_all on public.venues
  for all to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));

create policy bookings_admin_read on public.bookings
  for select to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'));
create policy bookings_admin_update on public.bookings
  for update to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));

create policy payments_admin_read on public.payments
  for select to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'));
create policy refunds_admin_read on public.refunds
  for select to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'));

create policy accommodation_properties_admin_all
  on public.accommodation_properties for all to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));
create policy accommodation_units_admin_all
  on public.accommodation_units for all to authenticated
  using (public.has_role((select auth.uid()), 'administrator') or
         public.has_role((select auth.uid()), 'super_administrator'))
  with check (public.has_role((select auth.uid()), 'administrator') or
              public.has_role((select auth.uid()), 'super_administrator'));

-- Hall child inventory remains owner-scoped by existing policies, with a
-- separate platform-admin policy for moderation and support operations.
do $policies$
declare table_name text;
begin
  foreach table_name in array array[
    'venue_images','venue_facilities','venue_operating_hours','time_slots',
    'pricing_rules','venue_blocked_dates'
  ] loop
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (public.has_role((select auth.uid()), ''administrator'') or '
      'public.has_role((select auth.uid()), ''super_administrator'')) '
      'with check (public.has_role((select auth.uid()), ''administrator'') or '
      'public.has_role((select auth.uid()), ''super_administrator''))',
      table_name || '_admin_all', table_name
    );
  end loop;
end
$policies$;

grant select on public.profiles, public.owner_profiles, public.organizations,
  public.venues, public.bookings, public.payments, public.refunds,
  public.platform_commissions, public.audit_logs, public.disputes,
  public.accommodation_properties, public.accommodation_units,
  public.stay_bookings, public.platform_settings to authenticated;
grant insert, update, delete on public.platform_settings to authenticated;

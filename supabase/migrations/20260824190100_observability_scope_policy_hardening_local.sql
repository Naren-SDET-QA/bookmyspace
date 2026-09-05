-- Policy hardening for the trusted scope migration. Additive and local-only.
drop policy if exists observability_scoped_health on public.health_checks;
create policy observability_scoped_health on public.health_checks for select to authenticated using (
  public.is_platform_admin((select auth.uid())) or
  (organization_id is not null and exists (select 1 from public.organizations o where o.id = health_checks.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = health_checks.organization_id and cc.category_id = health_checks.category_id) or exists (select 1 from public.venues v where v.org_id = health_checks.organization_id and v.category_id = health_checks.category_id)))
);
drop policy if exists observability_scoped_errors on public.error_events;
create policy observability_scoped_errors on public.error_events for select to authenticated using (
  public.is_platform_admin((select auth.uid())) or
  (organization_id is not null and exists (select 1 from public.organizations o where o.id = error_events.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = error_events.organization_id and cc.category_id = error_events.category_id) or exists (select 1 from public.venues v where v.org_id = error_events.organization_id and v.category_id = error_events.category_id)))
);
drop policy if exists observability_scoped_alerts on public.alert_rules;
create policy observability_scoped_alerts on public.alert_rules for all to authenticated using (
  public.is_platform_admin((select auth.uid())) or
  (organization_id is not null and exists (select 1 from public.organizations o where o.id = alert_rules.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = alert_rules.organization_id and cc.category_id = alert_rules.category_id) or exists (select 1 from public.venues v where v.org_id = alert_rules.organization_id and v.category_id = alert_rules.category_id)))
) with check (
  public.is_platform_admin((select auth.uid())) or
  (organization_id is not null and exists (select 1 from public.organizations o where o.id = alert_rules.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = alert_rules.organization_id and cc.category_id = alert_rules.category_id) or exists (select 1 from public.venues v where v.org_id = alert_rules.organization_id and v.category_id = alert_rules.category_id)))
);
drop policy if exists observability_scoped_recovery on public.recovery_events;
create policy observability_scoped_recovery on public.recovery_events for select to authenticated using (
  public.is_platform_admin((select auth.uid())) or
  (organization_id is not null and exists (select 1 from public.organizations o where o.id = recovery_events.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = recovery_events.organization_id and cc.category_id = recovery_events.category_id) or exists (select 1 from public.venues v where v.org_id = recovery_events.organization_id and v.category_id = recovery_events.category_id)))
);
drop policy if exists recovery_state_scoped on public.observability_recovery_state;
create policy recovery_state_scoped on public.observability_recovery_state for select to authenticated using (
  public.is_platform_admin((select auth.uid())) or
  (exists (select 1 from public.organizations o where o.id = observability_recovery_state.organization_id and o.owner_user_id = (select auth.uid()) and o.is_active)
   and (category_id is null or exists (select 1 from public.organization_category_configurations cc where cc.organization_id = observability_recovery_state.organization_id and cc.category_id = observability_recovery_state.category_id) or exists (select 1 from public.venues v where v.org_id = observability_recovery_state.organization_id and v.category_id = observability_recovery_state.category_id)))
);

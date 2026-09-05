-- Additive local observability/help foundation. It observes existing truth;
-- it does not mutate bookings, payments, refunds, or inventory.
create table if not exists public.health_checks (
  id uuid primary key default gen_random_uuid(),
  feature text not null,
  status text not null check (status in ('healthy','warning','critical','disabled')),
  checked_at timestamptz not null default now(),
  response_ms integer,
  error_count integer not null default 0 check (error_count >= 0),
  details jsonb not null default '{}'::jsonb
);
create table if not exists public.error_events (
  id uuid primary key default gen_random_uuid(),
  feature text not null, category text, severity text not null default 'error',
  integration_id uuid references public.integrations(id) on delete set null,
  correlation_id text, retry_count integer not null default 0,
  status text not null default 'open', last_error text,
  created_at timestamptz not null default now(), resolved_at timestamptz,
  details jsonb not null default '{}'::jsonb
);
create table if not exists public.alert_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  feature text not null, condition text not null, operator text not null,
  threshold numeric not null, duration_seconds integer not null default 300,
  notify_email boolean not null default true, notify_whatsapp boolean not null default false,
  notify_push boolean not null default false, enabled boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.recovery_events (
  id uuid primary key default gen_random_uuid(),
  feature text not null, action text not null, status text not null,
  correlation_id text, created_at timestamptz not null default now(), details jsonb not null default '{}'::jsonb
);
create table if not exists public.help_articles (
  id uuid primary key default gen_random_uuid(), category text not null, title text not null,
  summary text not null default '', steps text not null default '', example text not null default '',
  common_errors text not null default '', troubleshooting text not null default '', related_configuration text not null default '',
  enabled boolean not null default true, sort_order integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists health_checks_feature_checked_idx on public.health_checks(feature, checked_at desc);
create index if not exists error_events_created_idx on public.error_events(created_at desc);
create index if not exists error_events_correlation_idx on public.error_events(correlation_id) where correlation_id is not null;
create index if not exists help_articles_category_order_idx on public.help_articles(category, sort_order) where enabled;

alter table public.health_checks enable row level security;
alter table public.error_events enable row level security;
alter table public.alert_rules enable row level security;
alter table public.recovery_events enable row level security;
alter table public.help_articles enable row level security;

create policy observability_admin_health on public.health_checks for select to authenticated
  using (public.is_platform_admin((select auth.uid())));
create policy observability_admin_errors on public.error_events for select to authenticated
  using (public.is_platform_admin((select auth.uid())));
create policy observability_admin_alerts on public.alert_rules for all to authenticated
  using (public.is_platform_admin((select auth.uid()))) with check (public.is_platform_admin((select auth.uid())));
create policy observability_admin_recovery on public.recovery_events for select to authenticated
  using (public.is_platform_admin((select auth.uid())));
create policy help_public_read on public.help_articles for select to anon, authenticated using (enabled);
create policy help_admin_write on public.help_articles for all to authenticated
  using (public.is_platform_admin((select auth.uid()))) with check (public.is_platform_admin((select auth.uid())));

revoke all on public.health_checks, public.error_events, public.alert_rules, public.recovery_events from anon;
grant select on public.health_checks, public.error_events, public.recovery_events to authenticated;
grant select, insert, update, delete on public.alert_rules to authenticated;
grant select on public.help_articles to anon, authenticated;
grant insert, update, delete on public.help_articles to authenticated;

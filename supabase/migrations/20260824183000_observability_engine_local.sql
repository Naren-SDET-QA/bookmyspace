alter table if exists public.help_articles add column if not exists language text not null default 'en';
alter table if exists public.help_articles add column if not exists archived_at timestamptz;
create index if not exists error_events_feature_severity_idx on public.error_events(feature, severity, created_at desc);
create index if not exists alert_rules_enabled_idx on public.alert_rules(enabled, feature) where enabled;
create index if not exists recovery_events_status_created_idx on public.recovery_events(status, created_at desc);

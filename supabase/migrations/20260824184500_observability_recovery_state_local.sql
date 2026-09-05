create table if not exists public.observability_recovery_state (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  category_id uuid references public.venue_categories(id) on delete set null,
  component text not null,
  provider text,
  state text not null check (state in ('HEALTHY','DEGRADED','RETRYING','CIRCUIT_OPEN','RECOVERING')),
  failure_count integer not null default 0 check (failure_count >= 0),
  retry_count integer not null default 0 check (retry_count >= 0),
  opened_at timestamptz,
  next_retry_at timestamptz,
  last_success_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now(),
  unique (organization_id, category_id, component, provider)
);
create index if not exists observability_recovery_state_due_idx on public.observability_recovery_state(state, next_retry_at);
alter table public.observability_recovery_state enable row level security;
drop policy if exists observability_recovery_state_admin on public.observability_recovery_state;
create policy observability_recovery_state_admin on public.observability_recovery_state for all to authenticated
  using (public.is_platform_admin((select auth.uid())))
  with check (public.is_platform_admin((select auth.uid())));
revoke all on public.observability_recovery_state from anon;
grant select, insert, update on public.observability_recovery_state to authenticated;

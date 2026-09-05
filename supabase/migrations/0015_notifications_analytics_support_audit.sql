-- ============================================================
-- BookMySpace — Migration 0015: Notifications, Analytics,
-- Crash Reporting, Support Tickets, Audit Log, Admin
--
-- Idempotent compatibility layer.
--
-- History note: 0006 already created notifications, audit_logs and
-- support_tickets (text status/priority + check constraints), and
-- 20260820090200_dev_reconciled_0015_engagement.sql reconciles those tables
-- in place (columns, indexes, RLS) and creates analytics_events and
-- crash_reports. This migration therefore only guarantees table shells
-- exist, adds the admin role and the ticket-resolution helper, and seeds a
-- demo support ticket. Schema/policy ownership stays with 0006 + the
-- reconciled migration so fresh provisioning reaches the same end state as
-- the reconciled DEV database.
-- ============================================================

-- ------------------------------------------------------------
-- Defensive shells (normally created by 0006 / reconciled 0015)
-- ------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  type text not null,
  data jsonb default '{}'::jsonb,
  read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- The user/read index is created by 20260820090200 once the `read` column
-- exists; do not reference post-reconciliation columns here.

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id uuid,
  event_type text not null,
  properties jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_analytics_event_type
  on public.analytics_events(event_type, created_at);
create index if not exists idx_analytics_user
  on public.analytics_events(user_id, created_at);

create table if not exists public.crash_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id uuid,
  error_message text not null,
  stack_trace text,
  platform text not null default 'flutter',
  version text not null default '1.0.0',
  properties jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_crash_reports_created
  on public.crash_reports(created_at);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  description text,
  category text,
  status text not null default 'open',
  priority text not null default 'medium',
  admin_reply text,
  admin_id uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id),
  user_id uuid,
  action text not null,
  entity_type text,
  entity_id uuid,
  details jsonb default '{}'::jsonb,
  ip_address text,
  user_agent text,
  created_at timestamptz not null default now()
);
-- Actor/action indexes are created by 20260820090200 once `actor_id`
-- exists; do not reference post-reconciliation columns here.

-- ------------------------------------------------------------
-- ADMIN ROLE
-- ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'admin') then
    create role admin;
  end if;
end $$;

grant admin to owner;

-- ------------------------------------------------------------
-- HELPER FUNCTIONS
-- ------------------------------------------------------------
create or replace function public.mark_ticket_resolved(p_ticket_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.support_tickets
  set status = 'resolved', resolved_at = now(), updated_at = now()
  where id = p_ticket_id;
  if not found then
    raise exception 'ticket not found' using errcode = 'P0001';
  end if;
end $$;

grant execute on function public.mark_ticket_resolved(uuid) to authenticated;

-- ------------------------------------------------------------
-- DEMO: seed a support ticket for testing (values match 0006 checks)
-- ------------------------------------------------------------
do $$
declare
  v_owner uuid;
begin
  select user_id into v_owner from public.owner_profiles where email = 'owner@demo.com';
  if v_owner is null then
    return;
  end if;

  insert into public.support_tickets (user_id, subject, description, category, status, priority)
  values (v_owner, 'Test ticket', 'This is a demo support ticket.', 'general', 'open', 'normal');
end $$;

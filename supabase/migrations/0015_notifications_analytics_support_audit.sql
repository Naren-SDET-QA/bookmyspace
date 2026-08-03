-- ============================================================
-- BookMySpace — Migration 0015: Notifications, Analytics,
-- Crash Reporting, Support Tickets, Audit Log, Admin
--
-- Adds in-app notification delivery, analytics event tracking,
-- crash log ingestion, a support ticket system, an audit log
-- for admin actions, and an admin role with RLS.
-- ============================================================

-- ------------------------------------------------------------
-- NOTIFICATIONS (in-app, per-user)
-- ------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null check (type in ('booking_confirmed', 'booking_cancelled', 'payment_received', 'refund_processed', 'system', 'support_reply', 'admin')),
  data jsonb default '{}'::jsonb,
  read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_notifications_user on public.notifications(user_id, read, created_at);

create trigger trg_notifications_updated_at
  before update on public.notifications
  for each row execute function public.set_updated_at();

-- RLS: users can read their own notifications and update read state.
alter table public.notifications enable row level security;

create policy "notifications_own" on public.notifications
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ------------------------------------------------------------
-- ANALYTICS EVENTS
-- ------------------------------------------------------------
create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id uuid,
  event_type text not null,
  properties jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_analytics_event_type on public.analytics_events(event_type, created_at);
create index idx_analytics_user on public.analytics_events(user_id, created_at);

-- RLS: anyone can insert their own analytics; read is admin-only.
alter table public.analytics_events enable row level security;

create policy "analytics_insert_own" on public.analytics_events
  for insert
  with check (auth.uid() = user_id or auth.uid() is null);

create policy "analytics_admin_read" on public.analytics_events
  for select
  using (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

-- ------------------------------------------------------------
-- CRASH REPORTS
-- ------------------------------------------------------------
create table public.crash_reports (
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

create index idx_crash_reports_created on public.crash_reports(created_at);

alter table public.crash_reports enable row level security;

create policy "crash_reports_insert" on public.crash_reports
  for insert
  with check (auth.uid() = user_id or auth.uid() is null);

create policy "crash_reports_admin_read" on public.crash_reports
  for select
  using (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

-- ------------------------------------------------------------
-- SUPPORT TICKETS
-- ------------------------------------------------------------
create type public.ticket_status as enum ('open', 'in_progress', 'resolved', 'closed');
create type public.ticket_priority as enum ('low', 'medium', 'high', 'urgent');

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  description text not null,
  status public.ticket_status not null default 'open',
  priority public.ticket_priority not null default 'medium',
  category text not null check (category in ('booking', 'payment', 'venue', 'general', 'other')),
  admin_reply text,
  admin_id uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_support_tickets_user on public.support_tickets(user_id, status);
create index idx_support_tickets_status on public.support_tickets(status, created_at);

alter table public.support_tickets enable row level security;

-- Users can read and update their own tickets.
create policy "tickets_own" on public.support_tickets
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Admins (owners) can read all tickets and update status/reply.
create policy "tickets_admin_read" on public.support_tickets
  for select
  using (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

create policy "tickets_admin_write" on public.support_tickets
  for update
  using (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

-- ------------------------------------------------------------
-- AUDIT LOG
-- ------------------------------------------------------------
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb default '{}'::jsonb,
  ip_address text,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_actor on public.audit_logs(actor_id, created_at);
create index idx_audit_logs_action on public.audit_logs(action, created_at);

alter table public.audit_logs enable row level security;

-- Admins can read all audit logs.
create policy "audit_admin_read" on public.audit_logs
  for select
  using (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

-- Admins can insert audit entries.
create policy "audit_admin_insert" on public.audit_logs
  for insert
  with check (exists (
    select 1 from public.owner_profiles op
    where op.user_id = auth.uid()
  ));

-- ------------------------------------------------------------
-- ADMIN ROLE
-- ------------------------------------------------------------
create role admin;

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
-- DEMO: seed a support ticket for testing
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
  values (v_owner, 'Test ticket', 'This is a demo support ticket.', 'general', 'open', 'medium')
  on conflict do nothing;
end $$;
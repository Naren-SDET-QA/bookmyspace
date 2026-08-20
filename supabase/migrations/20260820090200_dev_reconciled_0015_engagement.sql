-- DEV reconciliation for 0015. Existing notifications, audit_logs and
-- support_tickets were created by 0006; this migration alters them in place.

alter table public.notifications
  add column if not exists read boolean not null default false,
  add column if not exists read_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists dedupe_key text;

update public.notifications set read = is_read where is_read is not null;
alter table public.notifications alter column body set not null;
alter table public.notifications drop column if exists is_read;

drop index if exists public.idx_notifications_user;
create index if not exists idx_notifications_user_created_at
  on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_user_read_created_at
  on public.notifications(user_id, read, created_at);

drop policy if exists notifications_own on public.notifications;
create policy notifications_own on public.notifications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'trg_notifications_updated_at'
                 and tgrelid = 'public.notifications'::regclass) then
    create trigger trg_notifications_updated_at before update on public.notifications
      for each row execute function public.set_updated_at();
  end if;
end $$;

alter table public.audit_logs
  add column if not exists actor_id uuid references auth.users(id),
  add column if not exists user_agent text;
alter table public.audit_logs alter column details set default '{}'::jsonb;
update public.audit_logs set actor_id = user_id where actor_id is null and user_id is not null;

create index if not exists idx_audit_logs_actor on public.audit_logs(actor_id, created_at);
create index if not exists idx_audit_logs_action on public.audit_logs(action, created_at);

drop policy if exists audit_insert_any_auth on public.audit_logs;
drop policy if exists audit_read_admin on public.audit_logs;
drop policy if exists dev_audit_read on public.audit_logs;
drop policy if exists dev_audit_insert on public.audit_logs;
create policy dev_audit_read on public.audit_logs for select using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);
create policy dev_audit_insert on public.audit_logs for insert with check (auth.uid() is not null);

alter table public.support_tickets
  add column if not exists admin_reply text,
  add column if not exists admin_id uuid references auth.users(id);
alter table public.support_tickets alter column priority set default 'medium';
alter table public.support_tickets drop constraint if exists support_tickets_priority_check;
alter table public.support_tickets add constraint support_tickets_priority_check
  check (priority in ('low', 'medium', 'high', 'urgent'));

drop policy if exists tickets_own_or_support on public.support_tickets;
drop policy if exists dev_tickets_own on public.support_tickets;
drop policy if exists dev_tickets_admin_read on public.support_tickets;
drop policy if exists dev_tickets_admin_write on public.support_tickets;
create policy dev_tickets_own on public.support_tickets for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy dev_tickets_admin_read on public.support_tickets for select using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);
create policy dev_tickets_admin_write on public.support_tickets for update using (
  public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator')
);

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id uuid,
  event_type text not null,
  properties jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.analytics_events enable row level security;
drop policy if exists dev_analytics_insert on public.analytics_events;
create policy dev_analytics_insert on public.analytics_events for insert
  with check (auth.uid() = user_id or auth.uid() is null);

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
alter table public.crash_reports enable row level security;
drop policy if exists dev_crash_insert on public.crash_reports;
create policy dev_crash_insert on public.crash_reports for insert
  with check (auth.uid() = user_id or auth.uid() is null);

create or replace function public.mark_ticket_resolved(p_ticket_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update public.support_tickets
  set status = 'resolved', resolved_at = now(), updated_at = now()
  where id = p_ticket_id;
  if not found then raise exception 'ticket not found' using errcode = 'P0001'; end if;
end $$;
grant execute on function public.mark_ticket_resolved(uuid) to authenticated;

-- ============================================================
-- BookMySpace — Push Notifications (FCM/APNs)
--
-- Adds:
--   1. device_tokens: per-user, per-device push tokens, registered and
--      deregistered by the client on sign-in/sign-out
--      (DeviceTokenRepository / PushNotificationService).
--   2. push_outbox: a server-managed outbox mirroring the existing
--      email_outbox pattern (see 20260820170000_transactional_email_outbox.sql).
--      A trigger on public.notifications enqueues a push job for every new
--      in-app notification, and a batch worker (the send-push-outbox edge
--      function) sends it. This requires zero changes to the existing
--      notification-insert call sites: create-refund, owner-booking-manage,
--      razorpay-webhook, and SupabaseNotificationRepository.create().
-- ============================================================

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists idx_device_tokens_user on public.device_tokens(user_id);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_own on public.device_tokens;
create policy device_tokens_own on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_device_tokens_updated_at'
      and tgrelid = 'public.device_tokens'::regclass
  ) then
    create trigger trg_device_tokens_updated_at before update on public.device_tokens
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- ------------------------------------------------------------
-- push_outbox: mirrors email_outbox's claim/result pattern.
-- ------------------------------------------------------------
create table if not exists public.push_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  notification_id uuid references public.notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  data jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists push_outbox_ready_idx
  on public.push_outbox(status, next_attempt_at)
  where status in ('pending', 'sending');

alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_push_outbox_updated_at'
      and tgrelid = 'public.push_outbox'::regclass
  ) then
    create trigger trg_push_outbox_updated_at before update on public.push_outbox
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- Enqueue a push job for every new in-app notification. SECURITY DEFINER
-- so it can write to push_outbox (revoked from anon/authenticated) no
-- matter whether the insert into notifications came from the client
-- (authenticated role, RLS-permitted self-insert via
-- SupabaseNotificationRepository.create()) or an edge function
-- (service_role, e.g. razorpay-webhook / create-refund / owner-booking-manage).
create or replace function public.enqueue_push_for_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.push_outbox (event_key, notification_id, user_id, title, body, data)
  values (
    'notification.' || new.id,
    new.id,
    new.user_id,
    new.title,
    new.body,
    jsonb_build_object('type', new.type) || coalesce(new.data, '{}'::jsonb)
  )
  on conflict (event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_enqueue_push_for_notification on public.notifications;
create trigger trg_enqueue_push_for_notification
  after insert on public.notifications
  for each row execute function public.enqueue_push_for_notification();

create or replace function public.claim_push_outbox_batch(
  p_limit integer default 10,
  p_stale_after_minutes integer default 15
)
returns setof public.push_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select id
    from public.push_outbox
    where (status = 'pending' and next_attempt_at <= now())
       or (status = 'sending' and updated_at < now() - make_interval(mins => p_stale_after_minutes))
    order by created_at
    for update skip locked
    limit greatest(1, least(p_limit, 100))
  )
  update public.push_outbox p
  set status = 'sending', attempts = p.attempts + 1, updated_at = now()
  from candidates c
  where p.id = c.id
  returning p.*;
end;
$$;

revoke all on function public.claim_push_outbox_batch(integer, integer) from public, anon, authenticated;
grant execute on function public.claim_push_outbox_batch(integer, integer) to service_role;

create or replace function public.set_push_outbox_result(
  p_id uuid,
  p_status text,
  p_error text default null,
  p_retry_after_seconds integer default 300,
  p_max_attempts integer default 8
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.push_outbox
  set status = case
      when p_status = 'sent' then 'sent'
      when attempts >= p_max_attempts then 'failed'
      else 'pending'
    end,
    sent_at = case when p_status = 'sent' then now() else sent_at end,
    last_error = p_error,
    next_attempt_at = case when p_status = 'sent' then next_attempt_at
      else now() + make_interval(secs => greatest(30, p_retry_after_seconds)) end,
    updated_at = now()
  where id = p_id and status = 'sending';
end;
$$;

revoke all on function public.set_push_outbox_result(uuid, text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.set_push_outbox_result(uuid, text, text, integer, integer) to service_role;

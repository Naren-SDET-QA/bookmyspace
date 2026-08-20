-- Transactional email outbox. This table is server-managed only.
create table if not exists public.email_outbox (
  id uuid primary key default gen_random_uuid(),
  event_key text not null unique,
  event_type text not null,
  recipient_email text not null,
  recipient_name text,
  booking_id uuid references public.bookings(id) on delete set null,
  payment_id uuid references public.payments(id) on delete set null,
  refund_id uuid references public.refunds(id) on delete set null,
  invoice_id uuid,
  template_name text not null,
  payload jsonb not null default '{}'::jsonb,
  attachment_metadata jsonb not null default '[]'::jsonb,
  status text not null default 'pending' check (status in ('pending','sending','sent','failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists email_outbox_ready_idx
  on public.email_outbox(status, next_attempt_at)
  where status in ('pending','sending');

alter table public.email_outbox enable row level security;
revoke all on public.email_outbox from anon, authenticated;

create or replace function public.claim_email_outbox_batch(
  p_limit integer default 10,
  p_stale_after_minutes integer default 15
)
returns setof public.email_outbox
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  with candidates as (
    select id
    from public.email_outbox
    where (status = 'pending' and next_attempt_at <= now())
       or (status = 'sending' and updated_at < now() - make_interval(mins => p_stale_after_minutes))
    order by created_at
    for update skip locked
    limit greatest(1, least(p_limit, 100))
  )
  update public.email_outbox e
  set status = 'sending', attempts = e.attempts + 1, updated_at = now()
  from candidates c
  where e.id = c.id
  returning e.*;
end;
$$;

revoke all on function public.claim_email_outbox_batch(integer, integer) from public, anon, authenticated;
grant execute on function public.claim_email_outbox_batch(integer, integer) to service_role;

create or replace function public.set_email_outbox_result(
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
  update public.email_outbox
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

revoke all on function public.set_email_outbox_result(uuid, text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.set_email_outbox_result(uuid, text, text, integer, integer) to service_role;

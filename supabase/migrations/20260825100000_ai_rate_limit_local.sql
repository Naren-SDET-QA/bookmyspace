-- Local-only AI request limiter. It is intentionally independent from all
-- booking, payment, refund, and inventory tables.
create table if not exists public.ai_request_rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  provider text not null,
  window_start timestamptz not null,
  window_seconds integer not null check (window_seconds between 1 and 3600),
  request_count integer not null default 0 check (request_count >= 0),
  updated_at timestamptz not null default now(),
  unique (user_id, organization_id, provider, window_start)
);

create index if not exists ai_request_rate_limits_window_idx
  on public.ai_request_rate_limits(provider, window_start);

alter table public.ai_request_rate_limits enable row level security;
revoke all on public.ai_request_rate_limits from anon, authenticated;

create or replace function public.consume_ai_rate_limit(
  p_provider text,
  p_limit integer,
  p_window_seconds integer default 60,
  p_organization_id uuid default null
)
returns table(allowed boolean, request_count integer, retry_after_seconds integer)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_window_seconds integer := least(greatest(coalesce(p_window_seconds, 60), 1), 3600);
  v_limit integer := least(greatest(coalesce(p_limit, 1), 1), 1000);
  v_start timestamptz;
  v_count integer;
  v_id uuid;
begin
  if v_user_id is null or nullif(trim(p_provider), '') is null then
    return query select false, 0, v_window_seconds;
    return;
  end if;

  v_start := to_timestamp(floor(extract(epoch from clock_timestamp()) / v_window_seconds) * v_window_seconds);

  perform pg_advisory_xact_lock(hashtextextended(
    v_user_id::text || '|' || coalesce(p_organization_id::text, '') || '|' || trim(p_provider) || '|' || v_start::text,
    0
  ));

  select r.id, r.request_count into v_id, v_count
  from public.ai_request_rate_limits as r
  where r.user_id = v_user_id
    and r.organization_id is not distinct from p_organization_id
    and r.provider = trim(p_provider)
    and r.window_start = v_start
  order by r.id
  limit 1
  for update;

  if v_id is null then
    insert into public.ai_request_rate_limits(user_id, organization_id, provider, window_start, window_seconds, request_count)
    values (v_user_id, p_organization_id, trim(p_provider), v_start, v_window_seconds, 0)
    returning ai_request_rate_limits.id, ai_request_rate_limits.request_count into v_id, v_count;
  end if;

  update public.ai_request_rate_limits as r
  set request_count = r.request_count + 1, updated_at = now(), window_seconds = v_window_seconds
  where r.id = v_id
  returning r.request_count into v_count;

  return query select v_count <= v_limit, v_count,
    case when v_count <= v_limit then 0 else v_window_seconds - extract(epoch from (clock_timestamp() - v_start))::integer end;
end;
$$;

revoke all on function public.consume_ai_rate_limit(text, integer, integer, uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_rate_limit(text, integer, integer, uuid) to authenticated;

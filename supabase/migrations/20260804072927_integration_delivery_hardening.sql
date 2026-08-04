-- Retry-safe provider webhook processing. A failed handler may be reclaimed;
-- only a completed event is treated as a duplicate.
alter table public.webhook_events add column if not exists attempts integer not null default 0;
alter table public.webhook_events add column if not exists last_error text;
alter table public.webhook_events add column if not exists processing_started_at timestamptz;

create or replace function public.begin_webhook_event(
  p_provider text, p_event_id text, p_event_type text, p_payload jsonb
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_claimed boolean;
begin
  insert into public.webhook_events(provider,event_id,event_type,payload,attempts,processing_started_at)
  values(p_provider,p_event_id,p_event_type,p_payload,1,now())
  on conflict(provider,event_id) do update set
    event_type=excluded.event_type, payload=excluded.payload,
    attempts=public.webhook_events.attempts+1,
    processing_started_at=now(), last_error=null
  where public.webhook_events.processed=false
    and (public.webhook_events.processing_started_at is null
      or public.webhook_events.processing_started_at < now()-interval '2 minutes');
  get diagnostics v_claimed = row_count;
  return v_claimed;
end $$;

create or replace function public.complete_webhook_event(p_provider text,p_event_id text)
returns void language sql security definer set search_path=public,pg_temp as $$
  update public.webhook_events set processed=true,processed_at=now(),processing_started_at=null,last_error=null
  where provider=p_provider and event_id=p_event_id;
$$;

create or replace function public.fail_webhook_event(p_provider text,p_event_id text,p_error text)
returns void language sql security definer set search_path=public,pg_temp as $$
  update public.webhook_events set processing_started_at=null,last_error=left(coalesce(p_error,'processing failed'),500)
  where provider=p_provider and event_id=p_event_id and processed=false;
$$;

revoke all on function public.begin_webhook_event(text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.complete_webhook_event(text,text) from public,anon,authenticated;
revoke all on function public.fail_webhook_event(text,text,text) from public,anon,authenticated;
grant execute on function public.begin_webhook_event(text,text,text,jsonb) to service_role;
grant execute on function public.complete_webhook_event(text,text) to service_role;
grant execute on function public.fail_webhook_event(text,text,text) to service_role;

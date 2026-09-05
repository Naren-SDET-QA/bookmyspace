-- Local-only atomic circuit transitions. Reuses the existing observability
-- recovery state; no booking/payment state is touched.
create or replace function public.ai_circuit_admit(
  p_component text,
  p_provider text,
  p_organization_id uuid default null,
  p_category_id uuid default null,
  p_failure_threshold integer default 3,
  p_cooldown_seconds integer default 60
)
returns table(allowed boolean, state text, retry_after_seconds integer)
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_row public.observability_recovery_state%rowtype;
  v_threshold integer := least(greatest(coalesce(p_failure_threshold, 3), 1), 10);
  v_cooldown integer := least(greatest(coalesce(p_cooldown_seconds, 60), 1), 3600);
begin
  if nullif(trim(p_component), '') is null or nullif(trim(p_provider), '') is null then
    return query select false, 'DEGRADED', v_cooldown;
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    coalesce(p_organization_id::text, '') || '|' || coalesce(p_category_id::text, '') || '|' || trim(p_component) || '|' || trim(p_provider),
    0
  ));
  select * into v_row from public.observability_recovery_state
  where organization_id is not distinct from p_organization_id
    and category_id is not distinct from p_category_id
    and component = trim(p_component) and provider = trim(p_provider)
  order by id
  limit 1
  for update;
  if v_row.id is null then
    insert into public.observability_recovery_state(organization_id, category_id, component, provider, state)
    values (p_organization_id, p_category_id, trim(p_component), trim(p_provider), 'HEALTHY')
    returning * into v_row;
  end if;
  if v_row.state = 'CIRCUIT_OPEN' and (v_row.next_retry_at is null or v_row.next_retry_at > now()) then
    return query select false, v_row.state, greatest(1, ceil(extract(epoch from (v_row.next_retry_at - now())))::integer);
    return;
  end if;
  if v_row.state = 'CIRCUIT_OPEN' then
    update public.observability_recovery_state set state = 'RECOVERING', retry_count = retry_count + 1, updated_at = now() where id = v_row.id;
    return query select true, 'RECOVERING', 0;
    return;
  end if;
  return query select true, v_row.state, 0;
end;
$$;

create or replace function public.ai_circuit_record_result(
  p_component text,
  p_provider text,
  p_succeeded boolean,
  p_organization_id uuid default null,
  p_category_id uuid default null,
  p_failure_threshold integer default 3,
  p_cooldown_seconds integer default 60,
  p_error text default null
)
returns text
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_id uuid;
  v_failures integer;
  v_threshold integer := least(greatest(coalesce(p_failure_threshold, 3), 1), 10);
  v_cooldown integer := least(greatest(coalesce(p_cooldown_seconds, 60), 1), 3600);
  v_state text;
begin
  select id, failure_count into v_id, v_failures from public.observability_recovery_state
  where organization_id is not distinct from p_organization_id and category_id is not distinct from p_category_id
    and component = trim(p_component) and provider = trim(p_provider)
  order by id
  limit 1
  for update;
  if v_id is null then return 'DEGRADED'; end if;
  if p_succeeded then
    v_state := 'HEALTHY';
    update public.observability_recovery_state set state = v_state, failure_count = 0, retry_count = 0, last_success_at = now(), next_retry_at = null, last_error = null, updated_at = now() where id = v_id;
  else
    v_failures := v_failures + 1;
    v_state := case when v_failures >= v_threshold then 'CIRCUIT_OPEN' else 'DEGRADED' end;
    update public.observability_recovery_state set state = v_state, failure_count = v_failures, opened_at = case when v_state = 'CIRCUIT_OPEN' then coalesce(opened_at, now()) else opened_at end, next_retry_at = case when v_state = 'CIRCUIT_OPEN' then now() + make_interval(secs => v_cooldown) else null end, last_error = left(p_error, 500), updated_at = now() where id = v_id;
  end if;
  return v_state;
end;
$$;

revoke all on function public.ai_circuit_admit(text, text, uuid, uuid, integer, integer) from public, anon;
revoke all on function public.ai_circuit_record_result(text, text, boolean, uuid, uuid, integer, integer, text) from public, anon;
grant execute on function public.ai_circuit_admit(text, text, uuid, uuid, integer, integer) to authenticated;
grant execute on function public.ai_circuit_record_result(text, text, boolean, uuid, uuid, integer, integer, text) to authenticated;

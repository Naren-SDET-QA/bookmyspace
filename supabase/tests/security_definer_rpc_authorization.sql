-- Read-only regression test. Run after migrations are applied.
-- Confirms the previously anon/PUBLIC-executable SECURITY DEFINER RPCs are
-- now restricted to authenticated/service_role, and that the two functions
-- that used to accept an unchecked p_user_id/p_ticket_id now reference
-- auth.uid() in their body.
do $$
declare
  v_def text;
  v_fn record;
begin
  -- Grants: none of these should be callable by anon or PUBLIC any more.
  for v_fn in
    select * from (values
      ('delete_owner_account', array['uuid']),
      ('mark_ticket_resolved', array['uuid']),
      ('acquire_venue_hold', array['uuid','uuid','date','uuid','uuid','numeric','numeric','numeric','integer']),
      ('release_venue_hold', array['uuid','uuid']),
      ('my_enrolled_batches', array['uuid']),
      ('register_webhook_event', array['text','text','text','jsonb'])
    ) as t(proname, argtypes)
  loop
    if exists (
      select 1
      from information_schema.routine_privileges rp
      where rp.routine_schema = 'public'
        and rp.routine_name = v_fn.proname
        and rp.grantee in ('anon', 'PUBLIC')
        and rp.privilege_type = 'EXECUTE'
    ) then
      raise exception '% must not be executable by anon/PUBLIC', v_fn.proname;
    end if;
  end loop;

  -- register_webhook_event should also no longer be callable by authenticated
  -- (only the service-role razorpay-webhook edge function calls it).
  if exists (
    select 1
    from information_schema.routine_privileges rp
    where rp.routine_schema = 'public'
      and rp.routine_name = 'register_webhook_event'
      and rp.grantee = 'authenticated'
      and rp.privilege_type = 'EXECUTE'
  ) then
    raise exception 'register_webhook_event must not be executable by authenticated';
  end if;

  -- Body checks: the two functions that trusted a client-supplied id must
  -- now reference auth.uid() internally.
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'delete_owner_account';
  if v_def is null or v_def not ilike '%auth.uid()%' then
    raise exception 'delete_owner_account must check auth.uid()';
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'mark_ticket_resolved';
  if v_def is null or v_def not ilike '%auth.uid()%' then
    raise exception 'mark_ticket_resolved must check auth.uid()';
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'acquire_venue_hold';
  if v_def is null or v_def not ilike '%auth.uid()%' then
    raise exception 'acquire_venue_hold must check auth.uid()';
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'release_venue_hold';
  if v_def is null or v_def not ilike '%auth.uid()%' then
    raise exception 'release_venue_hold must check auth.uid()';
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'my_enrolled_batches';
  if v_def is null or v_def not ilike '%auth.uid()%' then
    raise exception 'my_enrolled_batches must check auth.uid()';
  end if;
end $$;

do $$
begin
  if to_regclass('public.device_tokens') is null then
    raise exception 'device_tokens missing';
  end if;
  if to_regclass('public.push_outbox') is null then
    raise exception 'push_outbox missing';
  end if;
  if not exists (
    select 1 from pg_class
    where oid = 'public.device_tokens'::regclass and relrowsecurity
  ) then
    raise exception 'device_tokens RLS missing';
  end if;
  if not exists (
    select 1 from pg_class
    where oid = 'public.push_outbox'::regclass and relrowsecurity
  ) then
    raise exception 'push_outbox RLS missing';
  end if;
  if not exists (
    select 1 from pg_proc where proname = 'claim_push_outbox_batch'
  ) then
    raise exception 'claim_push_outbox_batch missing';
  end if;
  if not exists (
    select 1 from pg_proc where proname = 'enqueue_push_for_notification'
  ) then
    raise exception 'enqueue_push_for_notification missing';
  end if;
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_enqueue_push_for_notification'
  ) then
    raise exception 'push enqueue trigger missing';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated')
     and has_table_privilege('authenticated', 'public.push_outbox', 'select')
  then
    raise exception 'authenticated can select push_outbox';
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated')
     and not has_table_privilege('authenticated', 'public.device_tokens', 'insert')
  then
    raise exception 'authenticated cannot insert device_tokens';
  end if;
end $$;

do $$
begin
  if to_regclass('public.health_checks') is null then raise exception 'health_checks missing'; end if;
  if to_regclass('public.error_events') is null then raise exception 'error_events missing'; end if;
  if to_regclass('public.alert_rules') is null then raise exception 'alert_rules missing'; end if;
  if to_regclass('public.recovery_events') is null then raise exception 'recovery_events missing'; end if;
  if to_regclass('public.help_articles') is null then raise exception 'help_articles missing'; end if;
  if not exists (select 1 from pg_class where oid='public.health_checks'::regclass and relrowsecurity) then raise exception 'health_checks RLS missing'; end if;
  if not exists (select 1 from pg_class where oid='public.error_events'::regclass and relrowsecurity) then raise exception 'error_events RLS missing'; end if;
end $$;

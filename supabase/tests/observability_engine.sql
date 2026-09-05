do $$
begin
  if to_regclass('public.observability_recovery_state') is null then raise exception 'recovery state missing'; end if;
  if not exists (select 1 from pg_class where oid='public.observability_recovery_state'::regclass and relrowsecurity) then raise exception 'recovery state RLS missing'; end if;
  if not exists (select 1 from pg_attribute where attrelid='public.help_articles'::regclass and attname='language' and not attisdropped) then raise exception 'help language missing'; end if;
  if not exists (select 1 from pg_attribute where attrelid='public.help_articles'::regclass and attname='archived_at' and not attisdropped) then raise exception 'help archive missing'; end if;
end $$;

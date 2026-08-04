-- Read-only production baseline validation. Extension-owned relations are
-- deliberately excluded from BookMySpace application-table RLS accounting.
begin transaction read only;

do $$
declare
  v_unprotected integer;
  v_postgis_owned boolean;
  v_geo_works boolean;
begin
  select count(*) into v_unprotected
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
    and not exists(
      select 1 from pg_depend d join pg_extension e on e.oid=d.refobjid
      where d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e'
    )
    and not c.relrowsecurity;
  if v_unprotected<>0 then
    raise exception '% BookMySpace application tables do not have RLS',v_unprotected;
  end if;

  select exists(
    select 1 from pg_class c
    join pg_depend d on d.classid='pg_class'::regclass and d.objid=c.oid and d.deptype='e'
    join pg_extension e on e.oid=d.refobjid
    where c.oid='public.spatial_ref_sys'::regclass and e.extname='postgis'
  ) into v_postgis_owned;
  if not v_postgis_owned then raise exception 'spatial_ref_sys is not PostGIS-owned'; end if;

  -- Managed-extension exception: Supabase's PostGIS installation owns this
  -- coordinate-reference catalog and manages its platform ACLs. It contains
  -- no BookMySpace user/business data, is excluded from application-table RLS
  -- accounting, and application code must never issue writes against it.
  raise notice 'accepted managed-extension exception: public.spatial_ref_sys (PostGIS/Supabase ACLs)';

  select public.st_distance(
    public.st_setsrid(public.st_makepoint(78.4867,17.385),4326)::public.geography,
    public.st_setsrid(public.st_makepoint(78.4868,17.3851),4326)::public.geography
  )>0 into v_geo_works;
  if not v_geo_works then raise exception 'PostGIS geolocation validation failed'; end if;

  if to_regclass('public.webhook_events') is null
    or to_regprocedure('public.apply_commerce_payment(uuid,text)') is null then
    raise exception 'commerce webhook dependencies are missing';
  end if;
end $$;

select count(*) as preserved_auth_users from auth.users;
rollback;

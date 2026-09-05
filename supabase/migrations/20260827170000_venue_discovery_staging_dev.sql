-- DEV venue discovery staging. Imported records never write directly to venues.
create table if not exists public.venue_discovery_jobs (
  id uuid primary key default gen_random_uuid(), requested_state text not null,
  requested_city text not null, requested_category text not null, source text not null,
  status text not null default 'RUNNING' check (status in ('RUNNING','COMPLETED','FAILED')),
  started_at timestamptz not null default now(), completed_at timestamptz,
  discovered_count integer not null default 0, staged_count integer not null default 0,
  duplicate_count integer not null default 0, error_message text
);
create table if not exists public.venue_discovery_staging (
  id uuid primary key default gen_random_uuid(), source text not null,
  source_place_id text not null, name text not null, address text, city text,
  district text, state text, latitude double precision not null, longitude double precision not null,
  phone text, website text, category text, source_url text, raw_metadata jsonb not null default '{}'::jsonb,
  job_id uuid references public.venue_discovery_jobs(id), status text not null default 'PENDING_REVIEW'
    check (status in ('PENDING_REVIEW','APPROVED','REJECTED','PUBLISHED')),
  venue_id uuid references public.venues(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(source, source_place_id)
);
alter table public.venues add column if not exists source text;
alter table public.venues add column if not exists source_place_id text;
create unique index if not exists venues_source_place_uidx on public.venues(source, source_place_id) where source is not null and source_place_id is not null;
alter table public.venue_discovery_jobs enable row level security;
alter table public.venue_discovery_staging enable row level security;
drop policy if exists venue_discovery_staging_admin_read on public.venue_discovery_staging;
create policy venue_discovery_staging_admin_read on public.venue_discovery_staging for select to authenticated using (public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'));
drop policy if exists venue_discovery_jobs_admin_read on public.venue_discovery_jobs;
create policy venue_discovery_jobs_admin_read on public.venue_discovery_jobs for select to authenticated using (public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator'));
create or replace function public.stage_discovered_venue(p_source text,p_source_place_id text,p_name text,p_address text,p_city text,p_district text,p_state text,p_latitude double precision,p_longitude double precision,p_phone text,p_website text,p_category text,p_source_url text,p_raw_metadata jsonb,p_job_id uuid)
returns public.venue_discovery_staging language plpgsql security definer set search_path=public as $$
declare r public.venue_discovery_staging;
begin
 if p_source is null or btrim(p_source)='' or p_source_place_id is null or btrim(p_source_place_id)='' then raise exception 'invalid_source_identity'; end if;
 insert into public.venue_discovery_staging(source,source_place_id,name,address,city,district,state,latitude,longitude,phone,website,category,source_url,raw_metadata,job_id)
 values(p_source,p_source_place_id,p_name,p_address,p_city,p_district,p_state,p_latitude,p_longitude,p_phone,p_website,p_category,p_source_url,coalesce(p_raw_metadata,'{}'::jsonb),p_job_id)
 on conflict (source,source_place_id) do update set updated_at=now() returning * into r;
 return r;
end $$;
revoke all on function public.stage_discovered_venue(text,text,text,text,text,text,text,double precision,double precision,text,text,text,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.stage_discovered_venue(text,text,text,text,text,text,text,double precision,double precision,text,text,text,text,jsonb,uuid) to service_role;
create or replace function public.review_discovered_venue(p_staging_id uuid,p_action text)
returns public.venue_discovery_staging language plpgsql security invoker set search_path=public as $$
declare r public.venue_discovery_staging;
begin
 if not (public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator')) then raise exception 'not_authorized'; end if;
 if p_action not in ('APPROVE','REJECT') then raise exception 'invalid_review_action'; end if;
 update public.venue_discovery_staging set status=case when p_action='APPROVE' then 'APPROVED' else 'REJECTED' end,updated_at=now() where id=p_staging_id and status='PENDING_REVIEW' returning * into r;
 if r.id is null then raise exception 'staging_record_not_pending'; end if;
 return r;
end $$;
grant execute on function public.review_discovered_venue(uuid,text) to authenticated;
create or replace function public.approve_discovered_venue(p_staging_id uuid)
returns public.venue_discovery_staging language plpgsql security definer set search_path=public as $$
declare s public.venue_discovery_staging; v public.venues; c uuid;
begin
 if not (public.has_role(auth.uid(),'administrator') or public.has_role(auth.uid(),'super_administrator')) then raise exception 'not_authorized'; end if;
 select * into s from public.venue_discovery_staging where id=p_staging_id for update;
 if s.id is null then raise exception 'staging_record_not_found'; end if;
 if s.status='REJECTED' then raise exception 'staging_record_rejected'; end if;
 select id into c from public.venue_categories where lower(name)=lower(s.category) or lower(slug)=lower(s.category) limit 1;
 if c is null then raise exception 'venue_category_not_found'; end if;
 insert into public.venues(source,source_place_id,name,address_line1,city,state,latitude,longitude,category_id,is_verified,is_active)
 values(s.source,s.source_place_id,s.name,s.address,s.city,s.state,s.latitude,s.longitude,c,false,false)
 on conflict (source,source_place_id) where source is not null and source_place_id is not null do update set name=excluded.name,address_line1=excluded.address_line1,city=excluded.city,state=excluded.state,latitude=excluded.latitude,longitude=excluded.longitude,category_id=excluded.category_id,updated_at=now()
 returning * into v;
 update public.venue_discovery_staging set status='APPROVED',venue_id=v.id,updated_at=now() where id=s.id returning * into s;
 return s;
end $$;
revoke all on function public.approve_discovered_venue(uuid) from public,anon;
grant execute on function public.approve_discovered_venue(uuid) to authenticated;

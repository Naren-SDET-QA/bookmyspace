create table public.registration_form_templates (
 id uuid primary key default gen_random_uuid(),owner_user_id uuid not null references auth.users(id) on delete cascade,
 name text not null,module_key text not null,status text not null default 'draft' check(status in('draft','published','archived')),
 current_version integer not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.registration_form_versions (
 id uuid primary key default gen_random_uuid(),template_id uuid not null references public.registration_form_templates(id) on delete cascade,
 version integer not null check(version>0),schema jsonb not null check(jsonb_typeof(schema)='object'),created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),published_at timestamptz,unique(template_id,version)
);
create table public.registration_form_bindings (
 id uuid primary key default gen_random_uuid(),module_key text not null,resource_id uuid,template_id uuid not null references public.registration_form_templates(id) on delete cascade,
 collection_stage text not null default 'pre_booking',created_by uuid not null references auth.users(id),is_active boolean not null default true,created_at timestamptz not null default now(),
 unique nulls not distinct(module_key,resource_id,collection_stage)
);
create table public.registration_submissions (
 id uuid primary key default gen_random_uuid(),template_id uuid not null references public.registration_form_templates(id),form_version_id uuid not null references public.registration_form_versions(id),
 booking_id uuid references public.bookings(id) on delete restrict,module_key text not null,subject_user_id uuid not null references auth.users(id),submitted_by uuid not null references auth.users(id),
 participant_index integer not null default 0 check(participant_index>=0),participant_scope text not null default 'primary' check(participant_scope in('primary','all')),
 collection_stage text not null,payload jsonb not null default '{}',created_at timestamptz not null default now()
);
create table public.registration_submission_files (
 id uuid primary key default gen_random_uuid(),submission_id uuid not null references public.registration_submissions(id) on delete cascade,
 field_key text not null,storage_path text not null unique,original_name text not null,mime_type text,size_bytes bigint not null check(size_bytes between 1 and 10485760),created_at timestamptz not null default now()
);
create index idx_registration_bindings_resource on public.registration_form_bindings(module_key,resource_id) where is_active;
create index idx_registration_submissions_booking on public.registration_submissions(booking_id);

alter table public.registration_form_templates enable row level security;alter table public.registration_form_versions enable row level security;
alter table public.registration_form_bindings enable row level security;alter table public.registration_submissions enable row level security;alter table public.registration_submission_files enable row level security;
create policy form_templates_read on public.registration_form_templates for select to authenticated using(status='published' or owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
create policy form_templates_owner on public.registration_form_templates for all to authenticated using(owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator')) with check(owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
create policy form_versions_read on public.registration_form_versions for select to authenticated using(published_at is not null or exists(select 1 from public.registration_form_templates t where t.id=template_id and(t.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy form_bindings_read on public.registration_form_bindings for select to authenticated using(is_active or created_by=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
create policy form_bindings_owner on public.registration_form_bindings for all to authenticated using(created_by=(select auth.uid()) or public.has_role((select auth.uid()),'administrator')) with check(created_by=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'));
create policy submissions_read on public.registration_submissions for select to authenticated using(submitted_by=(select auth.uid()) or subject_user_id=(select auth.uid()) or exists(select 1 from public.registration_form_templates t where t.id=template_id and(t.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
create policy submission_files_read on public.registration_submission_files for select to authenticated using(exists(select 1 from public.registration_submissions s join public.registration_form_templates t on t.id=s.template_id where s.id=submission_id and(s.submitted_by=(select auth.uid()) or s.subject_user_id=(select auth.uid()) or t.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator'))));
grant select,insert,update on public.registration_form_templates,public.registration_form_bindings to authenticated;
grant select on public.registration_form_versions,public.registration_submissions,public.registration_submission_files to authenticated;
revoke insert,update,delete on public.registration_form_versions,public.registration_submissions,public.registration_submission_files from anon,authenticated;

create or replace function public.create_registration_form(p_name text,p_module_key text,p_schema jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_id uuid;begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.owner_profiles where user_id=v_uid) and not public.has_role(v_uid,'administrator') then raise exception 'owner or admin required' using errcode='42501';end if;
 insert into public.registration_form_templates(owner_user_id,name,module_key,current_version)values(v_uid,trim(p_name),trim(p_module_key),1)returning id into v_id;
 insert into public.registration_form_versions(template_id,version,schema,created_by)values(v_id,1,p_schema,v_uid);return v_id;end$$;
revoke all on function public.create_registration_form(text,text,jsonb) from public,anon;grant execute on function public.create_registration_form(text,text,jsonb) to authenticated;

create or replace function public.save_registration_form_version(p_template_id uuid,p_schema jsonb)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_version int;begin
 perform 1 from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')) for update;if not found then raise exception 'not permitted' using errcode='42501';end if;
 select coalesce(max(version),0)+1 into v_version from public.registration_form_versions where template_id=p_template_id;
 insert into public.registration_form_versions(template_id,version,schema,created_by)values(p_template_id,v_version,p_schema,v_uid);
 update public.registration_form_templates set current_version=v_version,status='draft',updated_at=now() where id=p_template_id;return v_version;end$$;
revoke all on function public.save_registration_form_version(uuid,jsonb) from public,anon;grant execute on function public.save_registration_form_version(uuid,jsonb) to authenticated;

create or replace function public.publish_registration_form(p_template_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_version int;begin
 select current_version into v_version from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')) for update;if not found then raise exception 'not permitted' using errcode='42501';end if;
 update public.registration_form_versions set published_at=coalesce(published_at,now()) where template_id=p_template_id and version=v_version;
 update public.registration_form_templates set status='published',updated_at=now() where id=p_template_id;end$$;
revoke all on function public.publish_registration_form(uuid) from public,anon;grant execute on function public.publish_registration_form(uuid) to authenticated;

create or replace function public.bind_registration_form(p_template_id uuid,p_module_key text,p_resource_id uuid,p_collection_stage text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_id uuid;begin
 if not exists(select 1 from public.registration_form_templates where id=p_template_id and(owner_user_id=v_uid or public.has_role(v_uid,'administrator')))then raise exception 'not permitted' using errcode='42501';end if;
 insert into public.registration_form_bindings(module_key,resource_id,template_id,collection_stage,created_by)values(trim(p_module_key),p_resource_id,p_template_id,p_collection_stage,v_uid)
 on conflict(module_key,resource_id,collection_stage)do update set template_id=excluded.template_id,is_active=true returning id into v_id;return v_id;end$$;
revoke all on function public.bind_registration_form(uuid,text,uuid,text) from public,anon;grant execute on function public.bind_registration_form(uuid,text,uuid,text) to authenticated;

create or replace function public.submit_registration_form(p_template_id uuid,p_booking_id uuid,p_payload jsonb,p_participant_index integer default 0,p_participant_scope text default 'primary',p_collection_stage text default 'pre_booking')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$declare v_uid uuid:=auth.uid();v_version public.registration_form_versions;f jsonb;v_key text;v_value jsonb;v_id uuid;begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 select v.* into v_version from public.registration_form_versions v join public.registration_form_templates t on t.id=v.template_id where t.id=p_template_id and t.status='published' and v.version=t.current_version and v.published_at is not null;
 if not found then raise exception 'published form not found';end if;
 if p_booking_id is not null and not exists(select 1 from public.bookings where id=p_booking_id and user_id=v_uid)then raise exception 'booking not permitted' using errcode='42501';end if;
 for f in select * from jsonb_array_elements(coalesce(v_version.schema->'fields','[]'))loop
  if coalesce((f->>'enabled')::bool,true)=false then continue;end if;
  if coalesce(f->>'collection_stage','pre_booking')<>p_collection_stage then continue;end if;
  if coalesce(f->>'participant_scope','primary')='primary' and p_participant_index>0 then continue;end if;
  v_key:=f->>'key';v_value:=p_payload->v_key;
  if coalesce((f->>'required')::bool,false) and(v_value is null or v_value='null'::jsonb or v_value='""'::jsonb)then raise exception 'required field: %',v_key using errcode='22023';end if;
  if v_value is not null and f->>'type'='number' then begin perform(v_value#>>'{}')::numeric;exception when others then raise exception 'invalid number: %',v_key using errcode='22023';end;end if;
  if v_value is not null and coalesce(f#>>'{validation,pattern}','')<>'' and(v_value#>>'{}')!~(f#>>'{validation,pattern}')then raise exception 'invalid field: %',v_key using errcode='22023';end if;
 end loop;
 insert into public.registration_submissions(template_id,form_version_id,booking_id,module_key,subject_user_id,submitted_by,participant_index,participant_scope,collection_stage,payload)
 select p_template_id,v_version.id,p_booking_id,t.module_key,v_uid,v_uid,p_participant_index,p_participant_scope,p_collection_stage,p_payload from public.registration_form_templates t where t.id=p_template_id returning id into v_id;return v_id;end$$;
revoke all on function public.submit_registration_form(uuid,uuid,jsonb,integer,text,text) from public,anon;grant execute on function public.submit_registration_form(uuid,uuid,jsonb,integer,text,text) to authenticated;

create or replace function public.attach_registration_file(p_submission_id uuid,p_field_key text,p_storage_path text,p_original_name text,p_mime_type text,p_size_bytes bigint)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$declare v_id uuid;begin
 if not exists(select 1 from public.registration_submissions where id=p_submission_id and submitted_by=auth.uid())then raise exception 'not permitted' using errcode='42501';end if;
 if split_part(p_storage_path,'/',1)<>auth.uid()::text or split_part(p_storage_path,'/',2)<>p_submission_id::text then raise exception 'invalid storage path' using errcode='42501';end if;
 insert into public.registration_submission_files(submission_id,field_key,storage_path,original_name,mime_type,size_bytes)values(p_submission_id,p_field_key,p_storage_path,p_original_name,p_mime_type,p_size_bytes)returning id into v_id;return v_id;end$$;
revoke all on function public.attach_registration_file(uuid,text,text,text,text,bigint) from public,anon;grant execute on function public.attach_registration_file(uuid,text,text,text,text,bigint) to authenticated;

create or replace function public.registration_immutable()returns trigger language plpgsql as $$begin raise exception 'registration snapshots are immutable' using errcode='42501';end$$;
create or replace function public.registration_version_immutable()returns trigger language plpgsql as $$begin
 if tg_op='DELETE' then raise exception 'form versions are immutable' using errcode='42501';end if;
 if old.template_id<>new.template_id or old.version<>new.version or old.schema<>new.schema or old.created_by<>new.created_by or old.created_at<>new.created_at or old.published_at is not null then raise exception 'form versions are immutable' using errcode='42501';end if;return new;end$$;
create trigger registration_versions_immutable before update or delete on public.registration_form_versions for each row execute function public.registration_version_immutable();
create trigger registration_submissions_immutable before update or delete on public.registration_submissions for each row execute function public.registration_immutable();
create trigger registration_files_immutable before update or delete on public.registration_submission_files for each row execute function public.registration_immutable();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)values('registration-documents','registration-documents',false,10485760,array['image/jpeg','image/png','application/pdf'])on conflict(id)do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create policy registration_files_insert on storage.objects for insert to authenticated with check(bucket_id='registration-documents' and split_part(name,'/',1)=(select auth.uid())::text);
create policy registration_files_select on storage.objects for select to authenticated using(bucket_id='registration-documents' and(split_part(name,'/',1)=(select auth.uid())::text or exists(select 1 from public.registration_submission_files f join public.registration_submissions s on s.id=f.submission_id join public.registration_form_templates t on t.id=s.template_id where f.storage_path=name and(t.owner_user_id=(select auth.uid()) or public.has_role((select auth.uid()),'administrator')))));

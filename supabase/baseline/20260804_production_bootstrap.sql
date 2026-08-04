-- Production-only reference/configuration data and existing-user backfill.
-- This file never writes to auth.users and every write is conflict-safe.

begin;

insert into public.venue_categories (slug, name) values
  ('function_hall', 'Function Hall'),
  ('marriage_hall', 'Marriage Hall'),
  ('convention_center', 'Convention Center'),
  ('party_hall', 'Party Hall'),
  ('meeting_room', 'Meeting Room'),
  ('community_hall', 'Community Hall'),
  ('sports_ground', 'Sports Ground'),
  ('coworking_space', 'Coworking Space'),
  ('auditorium', 'Auditorium')
on conflict (slug) do update set name=excluded.name;

-- Preserve every existing Auth identity. Create only the application-side
-- customer records that the normal new-user trigger would have created.
insert into public.profiles(id,full_name,email,phone)
select u.id,
  coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name'),
  u.email,u.phone
from auth.users u
on conflict(id) do nothing;

insert into public.user_roles(user_id,role)
select u.id,'customer'::public.user_role from auth.users u
on conflict(user_id,role) do nothing;

-- Private registration documents are application configuration, not seed data.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('registration-documents','registration-documents',false,10485760,
  array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

do $$ begin
  if not exists(select 1 from pg_policies where schemaname='storage'
    and tablename='objects' and policyname='registration_files_insert') then
    create policy registration_files_insert on storage.objects for insert to authenticated
    with check(bucket_id='registration-documents' and split_part(name,'/',1)=(select auth.uid())::text);
  end if;
  if not exists(select 1 from pg_policies where schemaname='storage'
    and tablename='objects' and policyname='registration_files_select') then
    create policy registration_files_select on storage.objects for select to authenticated using(
      bucket_id='registration-documents' and(
        split_part(name,'/',1)=(select auth.uid())::text or exists(
          select 1 from public.registration_submission_files f
          join public.registration_submissions s on s.id=f.submission_id
          join public.registration_form_templates t on t.id=s.template_id
          where f.storage_path=name and(
            t.owner_user_id=(select auth.uid()) or
            public.has_role((select auth.uid()),'administrator')
          )
        )
      )
    );
  end if;
end $$;

-- TRUNCATE bypasses row-level policies and is never required by clients.
revoke truncate on all tables in schema public from anon,authenticated;
alter default privileges for role postgres in schema public
  revoke truncate on tables from anon,authenticated;

commit;

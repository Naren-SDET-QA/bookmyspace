-- DEV reconciliation for 0014. Do not run raw 0014 after 0001 or the
-- DEV seed reconciliation: organizations.owner_user_id already references
-- auth.users and owner_profiles already exists.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'owner') then
    create role owner;
  end if;
end $$;

create or replace function public.get_owner_user_id()
returns uuid language sql stable
as $$
  select p.user_id from public.owner_profiles p
  where p.user_id = (select auth.uid())
  limit 1
$$;

create or replace function public.register_owner(
  p_email text, p_password text, p_name text
)
returns uuid language plpgsql
as $$
declare v_owner_id uuid; v_user_id uuid;
begin
  insert into auth.users (id, email, raw_user_meta_data)
  values (gen_random_uuid(), p_email, jsonb_build_object('name', p_name))
  returning id into v_user_id;
  insert into public.owner_profiles (user_id, email, name)
  values (v_user_id, p_email, p_name)
  returning id into v_owner_id;
  return v_owner_id;
end $$;

alter table public.owner_profiles enable row level security;

drop policy if exists dev_owner_profiles_own on public.owner_profiles;
create policy dev_owner_profiles_own on public.owner_profiles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dev_owner_profiles_read on public.owner_profiles;
create policy dev_owner_profiles_read on public.owner_profiles
  for select using (public.get_owner_user_id() is not null);

create or replace function public.delete_owner_account(p_user_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  delete from public.owner_profiles where user_id = p_user_id;
  delete from auth.users where id = p_user_id;
end $$;

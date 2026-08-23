-- Secure owner registration completion.
-- Auth users are created only by Supabase Auth signUp. This function creates
-- the application owner profile and the one role allowed by owner signup.

create or replace function public.complete_owner_registration(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_owner_id uuid;
  v_name text := nullif(trim(p_name), '');
begin
  if v_user_id is null then
    raise exception 'authenticated session required' using errcode = '42501';
  end if;

  if v_name is null or length(v_name) > 200 then
    raise exception 'owner name is required' using errcode = '22023';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = v_user_id;

  if v_email is null then
    raise exception 'authenticated email is required' using errcode = '22023';
  end if;

  insert into public.owner_profiles (user_id, email, name)
  values (v_user_id, v_email, v_name)
  on conflict (user_id) do update
    set email = excluded.email,
        name = excluded.name;

  select op.id into v_owner_id
  from public.owner_profiles op
  where op.user_id = v_user_id;

  insert into public.user_roles (user_id, role, granted_by, revoked_at)
  values (v_user_id, 'venue_owner', v_user_id, null)
  on conflict (user_id, role) do update
    set granted_by = excluded.granted_by,
        granted_at = now(),
        revoked_at = null;

  return v_owner_id;
end;
$$;

revoke all on function public.complete_owner_registration(text) from public;
grant execute on function public.complete_owner_registration(text) to authenticated;

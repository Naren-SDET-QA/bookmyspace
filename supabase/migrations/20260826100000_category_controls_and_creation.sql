-- Database-backed category controls and admin creation.
-- Additive: uses the existing venue_categories.metadata contract.

create or replace function public.admin_create_category(
  p_slug text,
  p_name text,
  p_icon text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns public.venue_categories
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_category public.venue_categories;
  v_slug text := lower(trim(p_slug));
  v_name text := trim(p_name);
  v_metadata jsonb := jsonb_build_object(
    'active', coalesce((p_metadata->>'active')::boolean, true),
    'searchable', coalesce((p_metadata->>'searchable')::boolean, true),
    'bookable', coalesce((p_metadata->>'bookable')::boolean, true),
    'availability_enabled', coalesce((p_metadata->>'availability_enabled')::boolean, true),
    'offers_enabled', coalesce((p_metadata->>'offers_enabled')::boolean, true),
    'payments_enabled', coalesce((p_metadata->>'payments_enabled')::boolean, true),
    'location_enabled', coalesce((p_metadata->>'location_enabled')::boolean, true)
  ) || coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
    'localized_names', jsonb_build_object('en', v_name)
  );
begin
  if not (public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if v_slug !~ '^[a-z0-9]+([_-][a-z0-9]+)*$' then
    raise exception 'invalid_category_code' using errcode = '22023';
  end if;
  if v_name = '' then
    raise exception 'category_name_required' using errcode = '22023';
  end if;
  insert into public.venue_categories(slug, name, icon, metadata)
  values (v_slug, v_name, nullif(trim(p_icon), ''), v_metadata)
  returning * into v_category;
  return v_category;
exception when unique_violation then
  raise exception 'category_code_already_exists' using errcode = '23505';
end;
$$;

revoke all on function public.admin_create_category(text, text, text, jsonb) from public, anon;
grant execute on function public.admin_create_category(text, text, text, jsonb) to authenticated;

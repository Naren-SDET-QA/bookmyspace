-- India location master: mandal/village levels and many-to-many PIN mapping.
-- Additive: does not alter existing location RLS policies or seed fabricated PINs.

do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'location_nodes'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%level in%'
      and pg_get_constraintdef(c.oid) not ilike '%village%'
  loop
    execute format('alter table public.location_nodes drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.location_nodes
  drop constraint if exists location_nodes_level_check;
alter table public.location_nodes
  add constraint location_nodes_level_check
  check (level in (
    'country',
    'state_province',
    'district_county',
    'mandal_taluk_tehsil_block',
    'city_town',
    'village',
    'area_locality'
  ));

do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'location_suggestions'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%suggested_level in%'
      and pg_get_constraintdef(c.oid) not ilike '%village%'
  loop
    execute format(
      'alter table public.location_suggestions drop constraint %I',
      r.conname
    );
  end loop;
end $$;

alter table public.location_suggestions
  drop constraint if exists location_suggestions_suggested_level_check;
alter table public.location_suggestions
  add constraint location_suggestions_suggested_level_check
  check (
    suggested_level is null
    or suggested_level in (
      'country',
      'state_province',
      'district_county',
      'mandal_taluk_tehsil_block',
      'city_town',
      'village',
      'area_locality'
    )
  );

create table if not exists public.location_postal_codes (
  location_id uuid not null references public.location_nodes(id) on delete cascade,
  postal_code text not null check (postal_code ~ '^[0-9]{6}$'),
  created_at timestamptz not null default now(),
  primary key (location_id, postal_code)
);

create index if not exists location_postal_codes_pin_idx
  on public.location_postal_codes(postal_code);

comment on table public.location_postal_codes is
  'Many-to-many India PIN mapping: one PIN may have many locations, one location may have many PINs.';

alter table public.location_postal_codes enable row level security;

drop policy if exists location_postal_codes_public_read
  on public.location_postal_codes;
create policy location_postal_codes_public_read
  on public.location_postal_codes
  for select to anon, authenticated
  using (exists (
    select 1
    from public.location_nodes n
    where n.id = location_id
      and n.status = 'active'
      and n.approved_at is not null
  ));

drop policy if exists location_postal_codes_admin_manage
  on public.location_postal_codes;
create policy location_postal_codes_admin_manage
  on public.location_postal_codes
  for all to authenticated
  using (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  )
  with check (
    public.has_role(auth.uid(), 'administrator')
    or public.has_role(auth.uid(), 'super_administrator')
  );

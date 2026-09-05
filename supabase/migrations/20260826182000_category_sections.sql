-- Database-backed Home category sections. Idempotent and additive.
create table if not exists public.category_sections (
  id text primary key,
  name text not null,
  slug text not null unique,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.category_sections (id, name, slug, sort_order, is_active)
values
  ('lodge_rooms', 'Stay', 'stay', 10, true),
  ('function_halls', 'Spaces & Events', 'spaces_events', 20, true),
  ('institutes_classes', 'Learning & Classes', 'learning_classes', 30, true),
  ('sports_activities', 'Sports & Activities', 'sports_activities', 40, true)
on conflict (id) do update set
  name = excluded.name,
  slug = excluded.slug,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

do $$
declare
  unmapped integer;
begin
  select count(*) into unmapped
  from public.venue_categories
  where lower(slug) not in (
    'auditorium','banquet_hall','co_living','coaching','community_hall',
    'computer_it','convention_center','coworking_space','dance_academy',
    'exhibition_hall','function_hall','gents_pg','govt_hall','guest_house',
    'homestay','hostel','hotel','hotel_stay','hourly_room','institute',
    'ladies_pg','lodge','marriage_hall','meeting_room','music_class',
    'party_hall','party_lawn','pg_coliving','pg_hostel','resort',
    'sports_academy','sports_ground','student_hostel','temple'
  );
  if unmapped <> 0 then
    raise exception 'CATEGORY_MAPPING_REVIEW_REQUIRED: % unmapped categories', unmapped;
  end if;
end $$;

update public.venue_categories
set metadata = jsonb_set(
  jsonb_set(metadata, '{section_id}', to_jsonb(case
    when lower(slug) in ('hotel','hotel_stay','lodge','resort','guest_house',
      'homestay','hourly_room','hostel','student_hostel','co_living',
      'gents_pg','ladies_pg','pg_coliving','pg_hostel') then 'lodge_rooms'
    when lower(slug) in ('function_hall','marriage_hall','banquet_hall',
      'party_hall','party_lawn','convention_center','community_hall',
      'govt_hall','auditorium','meeting_room','coworking_space',
      'exhibition_hall','temple') then 'function_halls'
    when lower(slug) in ('institute','coaching','computer_it','dance_academy',
      'music_class') then 'institutes_classes'
    when lower(slug) in ('sports_ground','sports_academy') then 'sports_activities'
  end), true),
  '{section_sort_order}', to_jsonb(case
    when lower(slug) in ('hotel','hotel_stay','lodge','resort','guest_house',
      'homestay','hourly_room','hostel','student_hostel','co_living',
      'gents_pg','ladies_pg','pg_coliving','pg_hostel') then 10
    when lower(slug) in ('function_hall','marriage_hall','banquet_hall',
      'party_hall','party_lawn','convention_center','community_hall',
      'govt_hall','auditorium','meeting_room','coworking_space',
      'exhibition_hall','temple') then 20
    when lower(slug) in ('institute','coaching','computer_it','dance_academy',
      'music_class') then 30
    when lower(slug) in ('sports_ground','sports_academy') then 40
  end), true);

alter table public.category_sections enable row level security;
drop policy if exists category_sections_public_read on public.category_sections;
create policy category_sections_public_read on public.category_sections
for select using (is_active);
drop policy if exists category_sections_admin_write on public.category_sections;
create policy category_sections_admin_write on public.category_sections
for all to authenticated
using (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'))
with check (public.has_role(auth.uid(), 'administrator') or public.has_role(auth.uid(), 'super_administrator'));

grant select on public.category_sections to anon, authenticated;

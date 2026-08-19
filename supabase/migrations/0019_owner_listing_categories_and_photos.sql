-- ============================================================
-- BookMySpace — Migration 0019: Owner listing categories + photos
--
-- 1. Persist Function Hall / Lodge / PG / Institute owner categories
--    in venue_categories so Lodge/PG no longer depend on seed_dev.
-- 2. Public-read / owner-write Storage bucket for real photo uploads.
--    Gallery rows still live on public.venue_images (existing RLS).
-- ============================================================

insert into public.venue_categories (slug, name, icon) values
  -- Function halls (extras beyond 0002)
  ('banquet_hall', 'Party Hall / Banquet', 'celebration'),
  ('govt_hall', 'Government Hall', 'account_balance'),
  ('party_lawn', 'Open Lawn Ground', 'park'),
  -- Lodge / rooms (previously only in seed_dev as hotel_stay)
  ('hotel_stay', 'Hotel / Stay', 'hotel'),
  ('hotel', 'Hotel', 'hotel'),
  ('lodge', 'Lodge', 'bed'),
  ('guest_house', 'Guest House', 'house'),
  ('hourly_room', 'Hourly / Day Room', 'schedule'),
  ('resort', 'Resort / Homestay', 'spa'),
  ('homestay', 'Homestay', 'cottage'),
  -- PG / hostels (previously only in seed_dev as pg_coliving)
  ('pg_coliving', 'PG / Co-Living', 'apartment'),
  ('pg_hostel', 'PG / Hostel', 'apartment'),
  ('hostel', 'Hostel', 'apartment'),
  ('co_living', 'Co-living Spaces', 'groups'),
  ('gents_pg', 'Gents PG', 'man'),
  ('ladies_pg', 'Ladies PG', 'woman'),
  ('student_hostel', 'Student Hostel', 'school'),
  -- Institutes / classes (advertising listings)
  ('institute', 'Institute', 'school'),
  ('coaching', 'Coaching & Tuition', 'menu_book'),
  ('computer_it', 'Computer & IT Classes', 'computer'),
  ('dance_academy', 'Dance Academy', 'nightlife'),
  ('music_class', 'Music & Singing', 'music_note'),
  ('sports_academy', 'Sports Academy & Turfs', 'sports_tennis')
on conflict (slug) do nothing;

insert into storage.buckets (id, name, public)
values ('venue-images', 'venue-images', true)
on conflict (id) do nothing;

-- Path layout: {auth.uid()}/{venue_id}/{filename}
-- Public read so listing galleries work for customers.
-- Write/delete restricted to the owner's own folder.

drop policy if exists "venue_images_storage_public_read" on storage.objects;
create policy "venue_images_storage_public_read"
  on storage.objects for select
  using (bucket_id = 'venue-images');

drop policy if exists "venue_images_storage_owner_insert" on storage.objects;
create policy "venue_images_storage_owner_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'venue-images'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "venue_images_storage_owner_update" on storage.objects;
create policy "venue_images_storage_owner_update"
  on storage.objects for update
  using (
    bucket_id = 'venue-images'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "venue_images_storage_owner_delete" on storage.objects;
create policy "venue_images_storage_owner_delete"
  on storage.objects for delete
  using (
    bucket_id = 'venue-images'
    and auth.uid() is not null
    and (storage.foldername(name))[1] = auth.uid()::text
  );

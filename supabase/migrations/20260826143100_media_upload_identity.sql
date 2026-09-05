-- Stable client upload identity prevents duplicate metadata on retries.
alter table public.venue_images add column if not exists upload_key text;
create unique index if not exists venue_images_upload_key_uidx
  on public.venue_images(venue_id, upload_key)
  where upload_key is not null;

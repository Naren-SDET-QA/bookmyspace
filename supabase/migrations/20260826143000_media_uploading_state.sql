-- Extend the existing media state for bounded upload recovery.
alter table public.venue_images
  drop constraint if exists venue_images_processing_status_check;
alter table public.venue_images
  add constraint venue_images_processing_status_check
  check (processing_status in ('pending', 'uploading', 'processing', 'ready', 'failed'));

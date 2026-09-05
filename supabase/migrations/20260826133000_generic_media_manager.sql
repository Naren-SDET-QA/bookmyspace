-- Generic media foundation. Additive and safe for existing image rows.
alter table public.venue_images
  add column if not exists media_kind text not null default 'image',
  add column if not exists is_active boolean not null default true,
  add column if not exists title text,
  add column if not exists description text,
  add column if not exists content_type text,
  add column if not exists size_bytes bigint,
  add column if not exists processing_status text not null default 'ready';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'venue_images_media_kind_check') then
    alter table public.venue_images add constraint venue_images_media_kind_check
      check (media_kind in ('image', 'video', 'model_3d'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'venue_images_processing_status_check') then
    alter table public.venue_images add constraint venue_images_processing_status_check
      check (processing_status in ('pending', 'processing', 'ready', 'failed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'venue_images_size_bytes_check') then
    alter table public.venue_images add constraint venue_images_size_bytes_check
      check (size_bytes is null or size_bytes >= 0);
  end if;
end $$;

create index if not exists venue_images_active_order_idx
  on public.venue_images(venue_id, is_active, is_cover, sort_order);
create index if not exists venue_images_kind_status_idx
  on public.venue_images(media_kind, processing_status);

-- Existing categories retain their current behavior while missing media
-- capabilities receive explicit safe defaults. No category rows are created.
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"media_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'media_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"images_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'images_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"videos_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'videos_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"models_3d_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'models_3d_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"gallery_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'gallery_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"owner_upload_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'owner_upload_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"owner_edit_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'owner_edit_enabled');
update public.venue_categories set metadata = coalesce(metadata, '{}'::jsonb) || '{"public_media_enabled":true}'::jsonb where not (coalesce(metadata, '{}'::jsonb) ? 'public_media_enabled');

drop policy if exists venue_images_public_read on public.venue_images;
create policy venue_images_public_read on public.venue_images for select using (
  is_active and exists (
    select 1 from public.venues v
    join public.venue_categories c on c.id = v.category_id
    where v.id = venue_images.venue_id
      and coalesce((c.metadata->>'media_enabled')::boolean, false)
      and coalesce((c.metadata->>'public_media_enabled')::boolean, false)
  )
);

drop policy if exists venue_images_owner_write on public.venue_images;
create policy venue_images_owner_write on public.venue_images for all using (
  exists (
    select 1 from public.venues v
    join public.organizations o on o.id = v.org_id
    join public.venue_categories c on c.id = v.category_id
    where v.id = venue_images.venue_id and o.owner_user_id = (select auth.uid())
      and coalesce((c.metadata->>'media_enabled')::boolean, false)
      and coalesce((c.metadata->>'owner_upload_enabled')::boolean, false)
      and coalesce((c.metadata->>'owner_edit_enabled')::boolean, false)
  )
) with check (
  exists (
    select 1 from public.venues v
    join public.organizations o on o.id = v.org_id
    join public.venue_categories c on c.id = v.category_id
    where v.id = venue_images.venue_id and o.owner_user_id = (select auth.uid())
      and coalesce((c.metadata->>'media_enabled')::boolean, false)
      and coalesce((c.metadata->>'owner_upload_enabled')::boolean, false)
      and coalesce((c.metadata->>'owner_edit_enabled')::boolean, false)
      and ((venue_images.media_kind = 'image' and coalesce((c.metadata->>'images_enabled')::boolean, false))
        or (venue_images.media_kind = 'video' and coalesce((c.metadata->>'videos_enabled')::boolean, false))
        or (venue_images.media_kind = 'model_3d' and coalesce((c.metadata->>'models_3d_enabled')::boolean, false)))
  )
);

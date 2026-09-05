-- Enforce per-kind public visibility without changing venue or booking data.
drop policy if exists venue_images_public_read on public.venue_images;
create policy venue_images_public_read on public.venue_images for select using (
  is_active and exists (
    select 1
    from public.venues v
    join public.venue_categories c on c.id = v.category_id
    where v.id = venue_images.venue_id
      and coalesce((c.metadata->>'media_enabled')::boolean, false)
      and coalesce((c.metadata->>'public_media_enabled')::boolean, false)
      and (
        (venue_images.media_kind = 'image' and coalesce((c.metadata->>'images_enabled')::boolean, false))
        or (venue_images.media_kind = 'video' and coalesce((c.metadata->>'videos_enabled')::boolean, false))
        or (venue_images.media_kind = 'model_3d' and coalesce((c.metadata->>'models_3d_enabled')::boolean, false))
      )
  )
);

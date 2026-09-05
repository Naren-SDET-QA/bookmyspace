-- Reuse the existing module_feature_configs global row for persistent flags.
insert into public.module_feature_configs (module_key, venue_id, metadata)
select 'promotions', null, jsonb_build_object(
  'promotions_enabled', true,
  'banners_enabled', true,
  'offers_enabled', true,
  'discounts_enabled', false,
  'promotion_media_enabled', true,
  'category_targeting_enabled', true,
  'venue_targeting_enabled', true,
  'scheduling_enabled', true,
  'cta_enabled', true
)
where not exists (
  select 1 from public.module_feature_configs
  where module_key = 'promotions' and venue_id is null
);

drop policy if exists promotions_public_read on public.promotions;
create policy promotions_public_read on public.promotions for select using (
  coalesce((select metadata->>'promotions_enabled' = 'true' from public.module_feature_configs where module_key='promotions' and venue_id is null), false)
  and active
  and (start_at is null or start_at <= now())
  and (end_at is null or end_at > now())
  and (
    (not exists (select 1 from public.promotion_categories pc where pc.promotion_id = promotions.id)
     and not exists (select 1 from public.promotion_venues pv where pv.promotion_id = promotions.id))
    or (
      coalesce((select metadata->>'category_targeting_enabled' = 'true' from public.module_feature_configs where module_key='promotions' and venue_id is null), false)
      and exists (
        select 1 from public.promotion_categories pc join public.venue_categories c on c.id=pc.category_id
        where pc.promotion_id=promotions.id and c.metadata->>'active' = 'true' and c.metadata->>'offers_enabled' = 'true'
      )
    )
    or (
      coalesce((select metadata->>'venue_targeting_enabled' = 'true' from public.module_feature_configs where module_key='promotions' and venue_id is null), false)
      and exists (
        select 1 from public.promotion_venues pv join public.venues v on v.id=pv.venue_id join public.venue_categories c on c.id=v.category_id
        where pv.promotion_id=promotions.id and v.is_active and c.metadata->>'active' = 'true' and c.metadata->>'offers_enabled' = 'true'
      )
    )
  )
);

-- Generic category metadata alias: AI terminology -> authoritative category.
-- No duplicate category or schema column is introduced.
update public.venue_categories
set metadata = metadata
  || jsonb_build_object(
    'aliases', coalesce(metadata->'aliases', '[]'::jsonb) || '["sports court"]'::jsonb,
    'search_aliases', coalesce(metadata->'search_aliases', '[]'::jsonb) || '["sports court"]'::jsonb,
    'ai_aliases', coalesce(metadata->'ai_aliases', '[]'::jsonb) || '["sports court"]'::jsonb
  )
where slug = 'sports_ground';

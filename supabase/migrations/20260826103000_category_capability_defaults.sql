-- Explicit capability flags for existing categories.
-- Preserves the current behavior while allowing clients to fail closed when
-- a future row omits a capability flag.
update public.venue_categories
set metadata = jsonb_set(
  jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(coalesce(metadata, '{}'::jsonb), '{active}', to_jsonb(coalesce((metadata->>'active')::boolean, true)), true),
            '{searchable}', to_jsonb(coalesce((metadata->>'searchable')::boolean, true)), true
          ),
          '{bookable}', to_jsonb(coalesce((metadata->>'bookable')::boolean, true)), true
        ),
        '{availability_enabled}', to_jsonb(coalesce((metadata->>'availability_enabled')::boolean, true)), true
      ),
      '{offers_enabled}', to_jsonb(coalesce((metadata->>'offers_enabled')::boolean, coalesce((metadata->>'offer_visible')::boolean, true))), true
    ),
    '{payments_enabled}', to_jsonb(coalesce((metadata->>'payments_enabled')::boolean, true)), true
  ),
  '{location_enabled}', to_jsonb(coalesce((metadata->>'location_enabled')::boolean, true)), true
)
where metadata is null
   or not (metadata ? 'active' and metadata ? 'searchable' and metadata ? 'bookable'
       and metadata ? 'availability_enabled' and (metadata ? 'offers_enabled' or metadata ? 'offer_visible')
       and metadata ? 'payments_enabled' and metadata ? 'location_enabled');

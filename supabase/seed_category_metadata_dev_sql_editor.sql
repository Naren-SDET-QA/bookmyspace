-- BookMySpace DEV category metadata backfill.
-- Source: 20260822120000_flutter_parity_foundation.sql, section 8 only.
-- Run manually in the bookmyspace-dev SQL Editor. No schema changes or deletes.

begin;

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'function_halls', 'active', true, 'bookable', true,
  'booking_mode', 'instant', 'customer_action_label', 'Book Now',
  'pricing_mode', 'slot', 'availability_mode', 'slots',
  'media_configuration', 'images', 'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name),
  'registration_required', false, 'kyc_required', false,
  'registration_required_fields', '[]'::jsonb,
  'registration_optional_fields', '["notes"]'::jsonb,
  'booking_required_fields', '["date","guests"]'::jsonb,
  'booking_optional_fields', '["time"]'::jsonb
)
where slug in ('function_hall','marriage_hall','convention_center','party_hall',
  'meeting_room','community_hall','auditorium','banquet_hall','govt_hall','party_lawn')
  and (metadata is null or metadata = '{}'::jsonb);

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'lodge_rooms', 'active', true, 'bookable', true,
  'booking_mode', 'instant', 'customer_action_label', 'Book Stay',
  'pricing_mode', 'nightly', 'availability_mode', 'date_range',
  'media_configuration', 'images', 'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name),
  'registration_required', false, 'kyc_required', false,
  'registration_required_fields', '[]'::jsonb,
  'registration_optional_fields', '["notes"]'::jsonb,
  'booking_required_fields', '["check_in","check_out"]'::jsonb,
  'booking_optional_fields', '["guests"]'::jsonb
)
where slug in ('hotel_stay','hotel','lodge','guest_house','hourly_room','resort','homestay')
  and (metadata is null or metadata = '{}'::jsonb);

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'pg_hostels', 'active', true, 'bookable', true,
  'booking_mode', 'instant', 'customer_action_label', 'Reserve',
  'pricing_mode', 'monthly', 'availability_mode', 'move_in',
  'media_configuration', 'images', 'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name),
  'registration_required', true, 'kyc_required', true,
  'registration_required_fields', '["full_name","phone"]'::jsonb,
  'registration_optional_fields', '["notes"]'::jsonb,
  'booking_required_fields', '["move_in","duration","occupants"]'::jsonb,
  'booking_optional_fields', '["sharing"]'::jsonb
)
where slug in ('pg_coliving','pg_hostel','hostel','co_living','gents_pg','ladies_pg','student_hostel')
  and (metadata is null or metadata = '{}'::jsonb);

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'institutes_classes', 'active', true, 'bookable', false,
  'booking_mode', 'listing_only', 'customer_action_label', 'Enquire',
  'pricing_mode', 'course_fee', 'availability_mode', 'batches',
  'media_configuration', 'images', 'aliases', to_jsonb(array[name, slug]),
  'search_aliases', to_jsonb(array[name, slug]),
  'ai_aliases', to_jsonb(array[name, slug]),
  'localized_names', jsonb_build_object('en', name),
  'registration_required', true, 'kyc_required', false,
  'registration_required_fields', '["full_name","phone"]'::jsonb,
  'registration_optional_fields', '["notes"]'::jsonb,
  'booking_required_fields', '["course","schedule","student_name"]'::jsonb,
  'booking_optional_fields', '["mode"]'::jsonb
)
where slug in ('institute','coaching','computer_it','dance_academy','music_class','sports_academy','sports_ground')
  and (metadata is null or metadata = '{}'::jsonb);

update public.venue_categories set metadata = jsonb_build_object(
  'section', 'function_halls', 'active', true, 'bookable', true,
  'booking_mode', 'instant', 'customer_action_label', 'Book Now',
  'pricing_mode', 'slot', 'availability_mode', 'slots',
  'media_configuration', 'images',
  'aliases', to_jsonb(array[name, slug, 'coworking', 'co-working']),
  'search_aliases', to_jsonb(array[name, slug, 'coworking']),
  'ai_aliases', to_jsonb(array[name, slug, 'coworking']),
  'localized_names', jsonb_build_object('en', name),
  'registration_required', false, 'kyc_required', false,
  'registration_required_fields', '[]'::jsonb,
  'registration_optional_fields', '["notes"]'::jsonb,
  'booking_required_fields', '["date","guests"]'::jsonb,
  'booking_optional_fields', '["time"]'::jsonb
)
where slug = 'coworking_space' and (metadata is null or metadata = '{}'::jsonb);

insert into public.venue_categories (slug, name, icon, metadata) values
('temple','Temple','temple_hindu',jsonb_build_object(
  'section','function_halls','active',true,'bookable',true,'booking_mode','owner_approval',
  'customer_action_label','Request Slot','pricing_mode','slot','availability_mode','slots',
  'media_configuration','images','aliases','["temple","mandir","devasthanam"]'::jsonb,
  'search_aliases','["temple","mandir"]'::jsonb,'ai_aliases','["temple","mandir"]'::jsonb,
  'localized_names','{"en":"Temple","te":"గుడి","hi":"मंदिर"}'::jsonb)),
('exhibition_hall','Exhibition Hall','museum',jsonb_build_object(
  'section','function_halls','active',true,'bookable',true,'booking_mode','instant',
  'customer_action_label','Book Now','pricing_mode','slot','availability_mode','slots',
  'media_configuration','images','aliases','["exhibition","expo","trade show"]'::jsonb,
  'search_aliases','["exhibition","expo"]'::jsonb,'ai_aliases','["exhibition","expo"]'::jsonb,
  'localized_names','{"en":"Exhibition Hall"}'::jsonb))
on conflict (slug) do nothing;

commit;

-- Read-only verification query:
select name,
       metadata->>'section' as section,
       metadata->>'active' as active,
       metadata->>'bookable' as bookable,
       metadata->>'registration_required' as registration_required,
       metadata->>'kyc_required' as kyc_required
from public.venue_categories
where metadata is not null and metadata <> '{}'::jsonb
order by name;

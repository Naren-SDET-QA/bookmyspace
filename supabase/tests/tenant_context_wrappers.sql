-- Local read-only contract checks for Phase 6.5E.
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in (
  'resolve_tenant_context', 'runtime_feature_enabled_for_venue',
  'acquire_booking_hold_with_tenant', 'confirm_booking_with_tenant',
  'confirm_venue_booking_with_tenant', 'available_hotel_rooms_with_tenant',
  'acquire_hotel_room_hold_with_tenant', 'release_hotel_room_hold_with_tenant'
);

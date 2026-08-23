-- Align location_nodes.level CHECK with the Flutter LocationNodeLevel enum.
--
-- The cascading location selector exposes Mandal/Taluk/Tehsil/Block and
-- Village levels (lib/features/location/domain/location_node.dart), but the
-- CHECK constraint created in 20260820140000_global_location_master.sql only
-- allowed five levels, making those two levels impossible to persist and
-- their selectors permanently empty.
--
-- This migration widens the CHECK to the full application contract. It does
-- not insert or modify any rows; nodes at the new levels are added later via
-- admin approval flows or DEV seeds.

alter table public.location_nodes drop constraint if exists location_nodes_level_check;

alter table public.location_nodes add constraint location_nodes_level_check
  check (level in (
    'country',
    'state_province',
    'district_county',
    'mandal_taluk_tehsil_block',
    'city_town',
    'village',
    'area_locality'
  ));

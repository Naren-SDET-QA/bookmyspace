import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../location/location_providers.dart';
import 'domain/map_providers.dart';
import 'infrastructure/distance_service.dart';
import 'infrastructure/geolocator_gps.dart';
import 'infrastructure/google_places_geocoder.dart';
import 'infrastructure/nominatim_geocoder.dart';
import 'infrastructure/osm_raster_tiles.dart';
import 'infrastructure/osrm_router.dart';

/// OSM raster tiles (default map UI backend).
final mapTileProvider = Provider<MapTileProvider>(
  (ref) => const OsmRasterTiles(),
);

/// Nominatim is the default geocoder; Google Places only when explicitly enabled.
final geocodingProvider = Provider<GeocodingProvider>((ref) {
  if (AppConfig.useGooglePlaces) {
    final google = GooglePlacesGeocoder();
    if (google.isConfigured) return google;
  }
  return NominatimGeocoder();
});

/// Always-available Nominatim (for tests / dual wiring).
final nominatimGeocoderProvider = Provider<NominatimGeocoder>(
  (ref) => NominatimGeocoder(),
);

final routingProvider = Provider<RoutingProvider>(
  (ref) => OsrmRouter(),
);

final locationProvider = Provider<LocationProvider>((ref) {
  return GeolocatorGps(
    deviceLocation: ref.watch(deviceLocationServiceProvider),
  );
});

final distanceServiceProvider = Provider<DistanceService>((ref) {
  return DistanceService(routing: ref.watch(routingProvider));
});

import 'geo_point.dart';

/// Provides raster map tile configuration (OSM by default).
abstract class MapTileProvider {
  /// flutter_map URL template with `{z}`, `{x}`, `{y}` placeholders.
  String get urlTemplate;

  /// User-Agent / package name for tile requests.
  String get userAgentPackageName;

  /// Attribution text shown on the map chrome.
  String get attribution;
}

/// Address ↔ coordinates geocoding.
abstract class GeocodingProvider {
  /// Whether this provider is ready (e.g. optional Google key present).
  bool get isConfigured;

  Future<List<GeocodedPlace>> searchAddress(
    String query, {
    int limit = 5,
  });

  Future<GeocodedPlace?> reverseGeocode(GeoPoint point);
}

/// Distance / route provider (OSRM by default).
abstract class RoutingProvider {
  bool get isConfigured;

  /// Driving route between [from] and [to]. Returns null on failure.
  Future<RouteResult?> route(GeoPoint from, GeoPoint to);

  /// Preferred distance in meters: route distance when available, else null.
  Future<double?> distanceMeters(GeoPoint from, GeoPoint to);
}

/// Device GPS location.
abstract class LocationProvider {
  Future<GeoPoint?> currentPosition();
}

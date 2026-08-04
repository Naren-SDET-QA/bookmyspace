import '../domain/geo_math.dart';
import '../domain/geo_point.dart';
import '../domain/map_providers.dart';

/// Distance between two points: OSRM when useful, else haversine.
class DistanceService {
  DistanceService({RoutingProvider? routing}) : _routing = routing;

  final RoutingProvider? _routing;

  /// Always-available great-circle distance in km.
  double haversineKm(GeoPoint from, GeoPoint to) =>
      GeoMath.haversineKm(from, to);

  /// Prefer OSRM road distance; fall back to haversine on failure.
  Future<double> distanceKm(GeoPoint from, GeoPoint to) async {
    final router = _routing;
    if (router != null && router.isConfigured) {
      try {
        final meters = await router.distanceMeters(from, to);
        if (meters != null) return meters / 1000.0;
      } catch (_) {
        // Fall through to haversine.
      }
    }
    return haversineKm(from, to);
  }
}

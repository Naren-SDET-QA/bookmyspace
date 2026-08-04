import 'dart:math' as math;

import 'geo_point.dart';

/// Local geodesic helpers (no network).
class GeoMath {
  const GeoMath._();

  static const double earthRadiusKm = 6371.0;
  static const double earthRadiusMeters = 6371000.0;

  /// Great-circle distance in kilometres (haversine).
  static double haversineKm(GeoPoint a, GeoPoint b) =>
      haversineMeters(a, b) / 1000.0;

  /// Great-circle distance in metres (haversine).
  static double haversineMeters(GeoPoint a, GeoPoint b) {
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
  }

  /// True when [point] is within [radiusKm] of [center].
  static bool withinRadiusKm(
    GeoPoint center,
    GeoPoint point,
    double radiusKm,
  ) =>
      haversineKm(center, point) <= radiusKm;

  static double _toRad(double deg) => deg * math.pi / 180.0;
}

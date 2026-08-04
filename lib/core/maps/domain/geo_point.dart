/// Latitude/longitude pair used across map providers.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0 && longitude == 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// A geocoded place result (address ↔ coordinates).
class GeocodedPlace {
  const GeocodedPlace({
    required this.displayName,
    required this.point,
    this.placeId,
  });

  final String displayName;
  final GeoPoint point;
  final String? placeId;
}

/// A routed path between two points.
class RouteResult {
  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometryPolyline,
  });

  final double distanceMeters;
  final double durationSeconds;
  final String? geometryPolyline;

  double get distanceKm => distanceMeters / 1000.0;
}

/// Marker shown on [MapView].
class MapMarkerData {
  const MapMarkerData({
    required this.point,
    this.id,
    this.label,
  });

  final GeoPoint point;
  final String? id;
  final String? label;
}

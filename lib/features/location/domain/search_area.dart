/// The area within which search results are scoped.
///
/// Drives both the location bar (label + radius) and the geolocated
/// fields of [VenueSearchQuery] (`latitude` / `longitude` /
/// `maxDistanceKm`).
class SearchArea {
  const SearchArea({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.radiusKm = 10,
    this.locationNodeId,
    this.countryCode,
    this.country,
    this.state,
    this.district,
    this.city,
    this.area,
    this.timezone,
  });

  final String label;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? locationNodeId;
  final String? countryCode;
  final String? country;
  final String? state;
  final String? district;
  final String? city;
  final String? area;
  final String? timezone;

  /// Valid latitude/longitude values that can safely be sent to maps or RPCs.
  bool get hasValidCoordinates => isValidCoordinate(latitude, longitude);

  static bool isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  SearchArea copyWith({
    String? label,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? locationNodeId,
    String? countryCode,
    String? country,
    String? state,
    String? district,
    String? city,
    String? area,
    String? timezone,
  }) {
    final next = SearchArea(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      locationNodeId: locationNodeId ?? this.locationNodeId,
      countryCode: countryCode ?? this.countryCode,
      country: country ?? this.country,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      area: area ?? this.area,
      timezone: timezone ?? this.timezone,
    );
    if (!next.hasValidCoordinates) return this;
    return next;
  }

  /// Default development area (Hyderabad, Madhapur) so the app renders
  /// real data before the user grants location permission. The radius is
  /// large enough to cover the city centre plus Secunderabad.
  /// Configurable fallback used only when GPS/location master resolution is
  /// unavailable. DEV keeps the established Hyderabad fallback; deployments
  /// can provide a different global default without code changes.
  static SearchArea get defaultArea => SearchArea(
    label: const String.fromEnvironment(
      'DEFAULT_LOCATION_LABEL',
      defaultValue: 'Hyderabad (Madhapur)',
    ),
    latitude:
        double.tryParse(
          const String.fromEnvironment(
            'DEFAULT_LOCATION_LAT',
            defaultValue: '17.4483',
          ),
        ) ??
        17.4483,
    longitude:
        double.tryParse(
          const String.fromEnvironment(
            'DEFAULT_LOCATION_LNG',
            defaultValue: '78.3915',
          ),
        ) ??
        78.3915,
    radiusKm:
        double.tryParse(
          const String.fromEnvironment(
            'DEFAULT_LOCATION_RADIUS_KM',
            defaultValue: '25',
          ),
        ) ??
        25,
  );

  static const List<SearchArea> popularAreas = [
    SearchArea(
      label: 'Hyderabad (Madhapur / Hitec City)',
      latitude: 17.4483,
      longitude: 78.3915,
    ),
    SearchArea(
      label: 'Hyderabad (Gachibowli)',
      latitude: 17.4401,
      longitude: 78.3489,
    ),
    SearchArea(
      label: 'Hyderabad (Kukatpally)',
      latitude: 17.4948,
      longitude: 78.4002,
    ),
    SearchArea(
      label: 'Hyderabad (Secunderabad)',
      latitude: 17.4399,
      longitude: 78.4983,
    ),
    SearchArea(
      label: 'Bengaluru (Koramangala)',
      latitude: 12.9352,
      longitude: 77.6245,
    ),
    SearchArea(
      label: 'Bengaluru (Whitefield)',
      latitude: 12.9698,
      longitude: 77.75,
    ),
    SearchArea(
      label: 'Mumbai (Andheri)',
      latitude: 19.1197,
      longitude: 72.8464,
    ),
    SearchArea(
      label: 'Delhi NCR (Gurugram)',
      latitude: 28.4595,
      longitude: 77.0266,
    ),
  ];

  static const List<double> radiusOptions = [5, 10, 25, 50];
}

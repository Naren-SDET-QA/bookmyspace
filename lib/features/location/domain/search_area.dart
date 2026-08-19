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
  });

  final String label;
  final double latitude;
  final double longitude;
  final double radiusKm;

  SearchArea copyWith({
    String? label,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) {
    return SearchArea(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  /// Default development area (Hyderabad, Madhapur) so the app renders
  /// real data before the user grants location permission. The radius is
  /// large enough to cover the city centre plus Secunderabad.
  static const SearchArea defaultArea = SearchArea(
    label: 'Hyderabad (Madhapur)',
    latitude: 17.4483,
    longitude: 78.3915,
    radiusKm: 25,
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
import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../domain/geo_point.dart';
import '../domain/map_providers.dart';

/// Optional Google Places geocoder — unused unless [AppConfig.useGooglePlaces].
///
/// Core flows must not depend on this; Nominatim is the default.
class GooglePlacesGeocoder implements GeocodingProvider {
  GooglePlacesGeocoder({
    String? apiKey,
    Dio? dio,
    this.searchUrl = 'https://places.googleapis.com/v1/places:searchText',
  })  : _apiKey = (apiKey ?? AppConfig.googlePlacesApiKey).trim(),
        _dio = dio ?? Dio();

  final String _apiKey;
  final Dio _dio;
  final String searchUrl;

  @override
  bool get isConfigured =>
      AppConfig.useGooglePlaces && _apiKey.isNotEmpty;

  @override
  Future<List<GeocodedPlace>> searchAddress(
    String query, {
    int limit = 5,
  }) async {
    if (!isConfigured) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];

    final response = await _dio.post<Map<String, dynamic>>(
      searchUrl,
      data: {
        'textQuery': q,
        'maxResultCount': limit.clamp(1, 5),
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location',
        },
      ),
    );

    final places = response.data?['places'];
    if (places is! List) return const [];
    return places
        .whereType<Map<Object?, Object?>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map(_fromPlace)
        .whereType<GeocodedPlace>()
        .toList();
  }

  @override
  Future<GeocodedPlace?> reverseGeocode(GeoPoint point) async {
    // Places Text Search is not ideal for reverse; keep optional & unused.
    if (!isConfigured) return null;
    return null;
  }

  GeocodedPlace? _fromPlace(Map<String, dynamic> place) {
    final location = place['location'];
    if (location is! Map) return null;
    final lat = (location['latitude'] as num?)?.toDouble();
    final lng = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final displayName = place['displayName'];
    final name = displayName is Map
        ? displayName['text'] as String?
        : place['formattedAddress'] as String?;
    if (name == null || name.isEmpty) return null;

    return GeocodedPlace(
      displayName: name,
      point: GeoPoint(lat, lng),
      placeId: place['id'] as String?,
    );
  }
}

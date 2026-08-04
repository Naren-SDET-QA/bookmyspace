import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../domain/geo_point.dart';
import '../domain/map_providers.dart';

/// Nominatim geocoder with light client-side rate limiting.
///
/// Follows https://operations.osmfoundation.org/policies/nominatim/
/// — identifiable User-Agent, max ~1 request/second.
class NominatimGeocoder implements GeocodingProvider {
  NominatimGeocoder({
    Dio? dio,
    String? baseUrl,
    String? userAgent,
    this.minInterval = const Duration(milliseconds: 1100),
  })  : _dio = dio ?? Dio(),
        _baseUrl = (baseUrl ?? AppConfig.nominatimBaseUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        _userAgent = userAgent ?? AppConfig.mapsUserAgent;

  final Dio _dio;
  final String _baseUrl;
  final String _userAgent;
  final Duration minInterval;

  DateTime? _lastRequestAt;

  @override
  bool get isConfigured => true;

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  Options get _options => Options(
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      );

  @override
  Future<List<GeocodedPlace>> searchAddress(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    await _throttle();
    final response = await _dio.get<List<dynamic>>(
      '$_baseUrl/search',
      queryParameters: {
        'q': q,
        'format': 'json',
        'limit': limit.clamp(1, 10),
        'addressdetails': 0,
      },
      options: _options,
    );

    final rows = response.data ?? const [];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map(_fromSearchRow)
        .whereType<GeocodedPlace>()
        .toList();
  }

  @override
  Future<GeocodedPlace?> reverseGeocode(GeoPoint point) async {
    await _throttle();
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/reverse',
      queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'json',
      },
      options: _options,
    );

    final data = response.data;
    if (data == null) return null;
    final display = data['display_name'] as String?;
    if (display == null || display.isEmpty) return null;

    final lat = double.tryParse('${data['lat']}') ?? point.latitude;
    final lon = double.tryParse('${data['lon']}') ?? point.longitude;
    return GeocodedPlace(
      displayName: display,
      point: GeoPoint(lat, lon),
      placeId: data['place_id']?.toString(),
    );
  }

  GeocodedPlace? _fromSearchRow(Map<String, dynamic> row) {
    final lat = double.tryParse('${row['lat']}');
    final lon = double.tryParse('${row['lon']}');
    final name = row['display_name'] as String?;
    if (lat == null || lon == null || name == null || name.isEmpty) {
      return null;
    }
    return GeocodedPlace(
      displayName: name,
      point: GeoPoint(lat, lon),
      placeId: row['place_id']?.toString(),
    );
  }
}

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../domain/geo_point.dart';
import '../domain/map_providers.dart';

/// OSRM public routing API for driving distance / duration.
class OsrmRouter implements RoutingProvider {
  OsrmRouter({
    Dio? dio,
    String? baseUrl,
    this.profile = 'driving',
  })  : _dio = dio ?? Dio(),
        _baseUrl = (baseUrl ?? AppConfig.osrmBaseUrl).replaceAll(
          RegExp(r'/+$'),
          '',
        );

  final Dio _dio;
  final String _baseUrl;
  final String profile;

  @override
  bool get isConfigured => true;

  @override
  Future<RouteResult?> route(GeoPoint from, GeoPoint to) async {
    final url =
        '$_baseUrl/route/v1/$profile/${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}';
    final response = await _dio.get<Map<String, dynamic>>(
      url,
      queryParameters: const {
        'overview': 'false',
        'alternatives': 'false',
      },
      options: Options(
        headers: {
          'User-Agent': AppConfig.mapsUserAgent,
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );

    final data = response.data;
    if (data == null || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map) return null;
    final map = Map<String, dynamic>.from(first);
    final distance = (map['distance'] as num?)?.toDouble();
    final duration = (map['duration'] as num?)?.toDouble();
    if (distance == null || duration == null) return null;
    return RouteResult(
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  @override
  Future<double?> distanceMeters(GeoPoint from, GeoPoint to) async {
    final result = await route(from, to);
    return result?.distanceMeters;
  }
}

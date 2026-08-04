import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/maps/domain/geo_math.dart';
import 'package:bookmyspace/core/maps/domain/geo_point.dart';
import 'package:bookmyspace/core/maps/infrastructure/google_places_geocoder.dart';
import 'package:bookmyspace/core/maps/infrastructure/nominatim_geocoder.dart';
import 'package:bookmyspace/core/maps/infrastructure/osm_raster_tiles.dart';
import 'package:bookmyspace/core/maps/infrastructure/osrm_router.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

void main() {
  group('GeoMath', () {
    test('haversine distance Ongole to Guntur is ~70–90 km', () {
      const ongole = GeoPoint(15.5057, 80.0495);
      const guntur = GeoPoint(16.3067, 80.4365);
      final km = GeoMath.haversineKm(ongole, guntur);
      expect(km, greaterThan(60));
      expect(km, lessThan(120));
    });

    test('withinRadiusKm rejects far points', () {
      const a = GeoPoint(15.5, 80.0);
      const b = GeoPoint(17.4, 78.5);
      expect(GeoMath.withinRadiusKm(a, b, 10), isFalse);
      expect(GeoMath.withinRadiusKm(a, a, 1), isTrue);
    });
  });

  group('OsmRasterTiles', () {
    test('defaults to AppConfig tile template', () {
      const tiles = OsmRasterTiles();
      expect(tiles.urlTemplate, AppConfig.osmTileUrlTemplate);
      expect(tiles.userAgentPackageName, AppConfig.mapsPackageName);
      expect(tiles.attribution, contains('OpenStreetMap'));
    });
  });

  group('AppConfig maps', () {
    test('Google Places is off by default', () {
      expect(AppConfig.useGooglePlaces, isFalse);
      expect(AppConfig.nominatimBaseUrl, contains('nominatim'));
      expect(AppConfig.osrmBaseUrl, contains('osrm'));
      expect(AppConfig.mapsUserAgent, contains('BookMySpace'));
    });
  });

  group('NominatimGeocoder mock HTTP', () {
    test('searchAddress parses results and sends User-Agent', () async {
      final dio = Dio();
      final adapter = _RecordingAdapter((options) async {
        expect(options.uri.path, contains('/search'));
        expect(options.headers['User-Agent'], contains('BookMySpace'));
        return ResponseBody.fromString(
          '''
[
  {"place_id":1,"lat":"15.5057","lon":"80.0495","display_name":"Ongole, AP"}
]
''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      dio.httpClientAdapter = adapter;

      final geocoder = NominatimGeocoder(
        dio: dio,
        baseUrl: 'https://nominatim.test',
        minInterval: Duration.zero,
      );
      final results = await geocoder.searchAddress('Ongole');
      expect(results, hasLength(1));
      expect(results.first.displayName, 'Ongole, AP');
      expect(results.first.point.latitude, closeTo(15.5057, 0.0001));
      expect(adapter.requests, hasLength(1));
    });

    test('reverseGeocode returns display name', () async {
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter((options) async {
        expect(options.uri.path, contains('/reverse'));
        return ResponseBody.fromString(
          '''
{"place_id":2,"lat":"15.5057","lon":"80.0495","display_name":"Ongole"}
''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final geocoder = NominatimGeocoder(
        dio: dio,
        baseUrl: 'https://nominatim.test',
        minInterval: Duration.zero,
      );
      final place = await geocoder.reverseGeocode(
        const GeoPoint(15.5057, 80.0495),
      );
      expect(place?.displayName, 'Ongole');
    });

    test('empty query returns empty list without HTTP', () async {
      final dio = Dio();
      var called = false;
      dio.httpClientAdapter = _RecordingAdapter((options) async {
        called = true;
        return ResponseBody.fromString('[]', 200);
      });
      final geocoder = NominatimGeocoder(
        dio: dio,
        minInterval: Duration.zero,
      );
      expect(await geocoder.searchAddress('  '), isEmpty);
      expect(called, isFalse);
    });
  });

  group('OsrmRouter mock HTTP', () {
    test('route parses distance and duration', () async {
      final dio = Dio();
      dio.httpClientAdapter = _RecordingAdapter((options) async {
        expect(options.uri.path, contains('/route/v1/driving/'));
        return ResponseBody.fromString(
          '''
{"code":"Ok","routes":[{"distance":12345.6,"duration":789.0}]}
''',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final router = OsrmRouter(dio: dio, baseUrl: 'https://osrm.test');
      final result = await router.route(
        const GeoPoint(15.5, 80.0),
        const GeoPoint(16.3, 80.4),
      );
      expect(result, isNotNull);
      expect(result!.distanceMeters, closeTo(12345.6, 0.1));
      expect(result.distanceKm, closeTo(12.3456, 0.001));
      expect(result.durationSeconds, closeTo(789.0, 0.1));
    });
  });

  group('GooglePlacesGeocoder optional', () {
    test('isConfigured is false without key / flag', () {
      final geocoder = GooglePlacesGeocoder(apiKey: '');
      expect(geocoder.isConfigured, isFalse);
    });
  });
}

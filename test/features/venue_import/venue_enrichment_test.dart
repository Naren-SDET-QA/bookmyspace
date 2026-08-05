import 'package:bookmyspace/features/venue_import/domain/venue_discovery.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_enrichment.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_enrichment_provider.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_enrichment_service.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_import_models.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/google_places_enrichment_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryEnrichmentProvider implements VenueEnrichmentProvider {
  _MemoryEnrichmentProvider(this.patch);

  final VenueEnrichmentPatch? patch;

  @override
  String get sourceCode => VenueDiscoverySources.googlePlaces;

  @override
  bool get isConfigured => true;

  @override
  Future<VenueEnrichmentPatch?> enrich(VenueEnrichmentRequest request) async =>
      patch;
}

void main() {
  group('VenueEnrichmentService merge/dedupe', () {
    late VenueEnrichmentService service;

    setUp(() {
      service = VenueEnrichmentService(_MemoryEnrichmentProvider(null));
    });

    VenueImportStagingRow osmRow({
      String id = 's1',
      String phone = '',
      String website = '',
      String googlePlaceId = '',
      List<Map<String, dynamic>> imageRefs = const [],
    }) =>
        VenueImportStagingRow(
          id: id,
          jobId: 'j1',
          name: 'Balaji Mandapam',
          categorySlug: 'function_hall',
          latitude: 15.834,
          longitude: 80.365,
          source: 'osm',
          sourcePlaceId: 'node/2647251777',
          phone: phone,
          website: website,
          googlePlaceId: googlePlaceId,
          imageRefs: imageRefs,
        );

    test('fills missing fields; preserves OSM source_place_id', () {
      final row = osmRow();
      const patch = VenueEnrichmentPatch(
        googlePlaceId: 'ChIJabc123',
        phone: '9876543210',
        website: 'https://example.com',
        imageRefs: [
          {'url': 'https://places.googleapis.com/v1/photo1/media', 'alt': 'Balaji'},
        ],
        ratings: {'avg': 4.2, 'count': 10, 'source': 'google_places'},
        provenance: {
          'google_places': {
            'place_id': 'ChIJabc123',
            'fetched_at': '2026-08-05T00:00:00Z',
          },
        },
      );

      final merged = service.applyPatch(row: row, patch: patch);
      expect(merged.source, 'osm');
      expect(merged.sourcePlaceId, 'node/2647251777');
      expect(merged.googlePlaceId, 'ChIJabc123');
      expect(merged.phone, '+919876543210');
      expect(merged.website, 'https://example.com');
      expect(merged.imageRefs.length, 1);
      expect(merged.ratings['avg'], 4.2);
      expect(merged.status, VenueImportStagingStatus.pendingReview);
      expect(
        Map<String, dynamic>.from(
          merged.enrichmentProvenance['google_places'] as Map,
        )['place_id'],
        'ChIJabc123',
      );
    });

    test('does not overwrite existing phone/website', () {
      final row = osmRow(phone: '+919111111111', website: 'https://owner.in');
      const patch = VenueEnrichmentPatch(
        googlePlaceId: 'ChIJxyz',
        phone: '9999999999',
        website: 'https://google.com',
      );

      final merged = service.applyPatch(row: row, patch: patch);
      expect(merged.phone, '+919111111111');
      expect(merged.website, 'https://owner.in');
      expect(merged.googlePlaceId, 'ChIJxyz');
    });

    test('dedupes image refs by url', () {
      final row = osmRow(
        imageRefs: [
          {'url': 'https://example.com/a.jpg', 'alt': 'A'},
        ],
      );
      const patch = VenueEnrichmentPatch(
        imageRefs: [
          {'url': 'https://example.com/a.jpg', 'alt': 'dup'},
          {'url': 'https://example.com/b.jpg', 'alt': 'B'},
        ],
      );

      final merged = service.applyPatch(row: row, patch: patch);
      expect(merged.imageRefs.length, 2);
      expect(merged.imageRefs.first['alt'], 'A');
    });

    test('rejects duplicate google_place_id across batch', () {
      final row = osmRow(id: 's2');
      const patch = VenueEnrichmentPatch(googlePlaceId: 'ChIJdup');

      expect(
        () => service.applyPatch(
          row: row,
          patch: patch,
          usedGooglePlaceIds: {'ChIJdup'},
        ),
        throwsA(isA<VenueEnrichmentException>()),
      );
    });

    test('mergeImageRefs helper dedupes case-insensitive urls', () {
      final merged = VenueEnrichmentService.mergeImageRefs(
        [
          {'url': 'HTTPS://Example.COM/x.jpg'},
        ],
        [
          {'url': 'https://example.com/x.jpg'},
          {'url': 'https://example.com/y.jpg'},
        ],
      );
      expect(merged.length, 2);
    });
  });

  group('GooglePlacesEnrichmentProvider mock HTTP', () {
    test('maps Places API v1 response to enrichment patch', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'places': [
                    {
                      'id': 'places/ChIJtest',
                      'displayName': {'text': 'Balaji Mandapam'},
                      'location': {'latitude': 15.8341, 'longitude': 80.3658},
                      'nationalPhoneNumber': '+91 98765 43210',
                      'websiteUri': 'https://balaji.example',
                      'rating': 4.5,
                      'userRatingCount': 42,
                      'regularOpeningHours': {
                        'weekdayDescriptions': ['Monday: 9:00 AM – 9:00 PM'],
                      },
                      'photos': [
                        {'name': 'places/ChIJtest/photos/abc'},
                      ],
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final provider = GooglePlacesEnrichmentProvider(
        apiKey: 'test-key-not-real',
        dio: dio,
      );

      final patch = await provider.enrich(
        const VenueEnrichmentRequest(
          stagingId: 's1',
          name: 'Balaji Mandapam',
          latitude: 15.834,
          longitude: 80.365,
          city: 'Ongole',
          state: 'Andhra Pradesh',
        ),
      );

      expect(patch, isNotNull);
      expect(patch!.googlePlaceId, 'places/ChIJtest');
      expect(patch.phone, contains('98765'));
      expect(patch.website, 'https://balaji.example');
      expect(patch.imageRefs, isNotEmpty);
      expect(patch.ratings['avg'], 4.5);
      expect(
        Map<String, dynamic>.from(
          patch.provenance[VenueDiscoverySources.googlePlaces] as Map,
        )['place_id'],
        'places/ChIJtest',
      );
    });

    test('returns null when no places match', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'places': const <dynamic>[]},
              ),
            );
          },
        ),
      );

      final provider = GooglePlacesEnrichmentProvider(
        apiKey: 'test-key',
        dio: dio,
      );

      final patch = await provider.enrich(
        const VenueEnrichmentRequest(
          stagingId: 's1',
          name: 'Unknown Hall',
          latitude: 15.0,
          longitude: 80.0,
        ),
      );
      expect(patch, isNull);
    });
  });
}

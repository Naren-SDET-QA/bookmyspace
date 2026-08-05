import 'package:bookmyspace/features/venue_import/domain/venue_discovery.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_discovery_pipeline.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_import_normalizer.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/noop_venue_discovery_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VenueDiscoveryPipeline validation', () {
    const pipeline = VenueDiscoveryPipeline(NoopVenueDiscoveryProvider());

    test('requires country, state, category slug', () {
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(country: '', state: 'AP', categorySlug: 'function_hall'),
        ),
        throwsA(isA<VenueDiscoveryValidationException>()),
      );
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(country: 'India', state: '', categorySlug: 'function_hall'),
        ),
        throwsA(isA<VenueDiscoveryValidationException>()),
      );
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(country: 'India', state: 'AP', categorySlug: ''),
        ),
        throwsA(isA<VenueDiscoveryValidationException>()),
      );
    });

    test('rejects invalid category slug and unknown source', () {
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(
            country: 'India',
            state: 'Andhra Pradesh',
            categorySlug: 'Function Hall',
          ),
        ),
        throwsA(isA<VenueDiscoveryValidationException>()),
      );
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(
            country: 'India',
            state: 'Andhra Pradesh',
            categorySlug: 'function_hall',
            sourceCode: 'scraped_site',
          ),
        ),
        throwsA(isA<VenueDiscoveryValidationException>()),
      );
    });

    test('accepts valid Country → State → Category', () {
      expect(
        () => pipeline.validateQuery(
          const VenueDiscoveryQuery(
            country: 'India',
            state: 'Andhra Pradesh',
            categorySlug: 'function_hall',
          ),
        ),
        returnsNormally,
      );
    });
  });

  group('normalize + dedupe', () {
    const pipeline = VenueDiscoveryPipeline(NoopVenueDiscoveryProvider());
    const query = VenueDiscoveryQuery(
      country: 'India',
      state: 'Andhra Pradesh',
      categorySlug: 'function_hall',
    );

    test('normalizes phone and address; fills query defaults', () {
      final raw = VenueDiscoveryCandidate(
        name: '  ABC   Hall ',
        categorySlug: '',
        latitude: 15.5,
        longitude: 80.0,
        phone: '98765 43210',
        addressLine1: '  MG   Road  ',
        provenance: VenueDiscoveryProvenance(
          sourceCode: VenueDiscoverySources.osm,
          fetchedAt: DateTime.utc(2026, 8, 4),
          sourcePlaceId: 'osm:123',
        ),
      );

      final n = pipeline.normalizeCandidate(raw, query: query);
      expect(n.name, 'ABC Hall');
      expect(n.phone, '+919876543210');
      expect(n.addressLine1, 'MG Road');
      expect(n.country, 'India');
      expect(n.state, 'Andhra Pradesh');
      expect(n.categorySlug, 'function_hall');
      expect(n.provenance.sourcePlaceId, 'osm:123');
      expect(n.provenance.sourceCode, VenueDiscoverySources.osm);
    });

    test('dedupes by source_place_id and name+location', () {
      final a = VenueDiscoveryCandidate(
        name: 'Hall One',
        categorySlug: 'function_hall',
        latitude: 15.501,
        longitude: 80.002,
        provenance: VenueDiscoveryProvenance(
          sourceCode: 'osm',
          fetchedAt: DateTime.utc(2026, 8, 4),
          sourcePlaceId: 'osm:1',
        ),
      );
      final dupPlace = a.copyWith(name: 'Hall One Renamed');
      final nearDup = VenueDiscoveryCandidate(
        name: 'Hall One',
        categorySlug: 'function_hall',
        latitude: 15.5012,
        longitude: 80.0021,
        provenance: VenueDiscoveryProvenance(
          sourceCode: 'osm',
          fetchedAt: DateTime.utc(2026, 8, 4),
          sourcePlaceId: 'osm:2',
        ),
      );
      final unique = VenueDiscoveryCandidate(
        name: 'Other Hall',
        categorySlug: 'function_hall',
        latitude: 16.0,
        longitude: 81.0,
        provenance: VenueDiscoveryProvenance(
          sourceCode: 'osm',
          fetchedAt: DateTime.utc(2026, 8, 4),
          sourcePlaceId: 'osm:3',
        ),
      );

      final result = pipeline.dedupe([a, dupPlace, nearDup, unique]);
      expect(result.length, 2);
      expect(result.map((c) => c.sourcePlaceId), ['osm:1', 'osm:3']);
      expect(
        isLikelyDuplicate(
          nameA: a.name,
          latA: a.latitude,
          lngA: a.longitude,
          nameB: nearDup.name,
          latB: nearDup.latitude,
          lngB: nearDup.longitude,
        ),
        isTrue,
      );
    });
  });

  group('pipeline run dry-run', () {
    test('noop provider returns empty unique set', () async {
      const pipeline = VenueDiscoveryPipeline(NoopVenueDiscoveryProvider());
      final result = await pipeline.run(
        const VenueDiscoveryQuery(
          country: 'India',
          state: 'Andhra Pradesh',
          categorySlug: 'function_hall',
        ),
      );
      expect(result.uniqueCount, 0);
      expect(result.duplicatesDropped, 0);
      expect(result.sourceCode, VenueDiscoverySources.osm);
      expect(result.candidates, isEmpty);
    });

    test('memory provider tracks source and drops duplicates', () async {
      final fetched = DateTime.utc(2026, 8, 5);
      final seed = [
        VenueDiscoveryCandidate(
          name: 'Sai Hall',
          categorySlug: 'function_hall',
          latitude: 15.5,
          longitude: 80.0,
          phone: '9999911111',
          provenance: VenueDiscoveryProvenance(
            sourceCode: VenueDiscoverySources.osm,
            fetchedAt: fetched,
            sourcePlaceId: 'osm:10',
          ),
        ),
        VenueDiscoveryCandidate(
          name: 'Sai Hall',
          categorySlug: 'function_hall',
          latitude: 15.5,
          longitude: 80.0,
          provenance: VenueDiscoveryProvenance(
            sourceCode: VenueDiscoverySources.osm,
            fetchedAt: fetched,
            sourcePlaceId: 'osm:10',
          ),
        ),
      ];

      final pipeline = VenueDiscoveryPipeline(
        MemoryVenueDiscoveryProvider(seed: seed),
      );
      final result = await pipeline.run(
        const VenueDiscoveryQuery(
          country: 'India',
          state: 'Andhra Pradesh',
          categorySlug: 'function_hall',
        ),
      );

      expect(result.uniqueCount, 1);
      expect(result.duplicatesDropped, 1);
      expect(result.candidates.single.phone, '+919999911111');
      expect(result.candidates.single.provenance.sourceCode, 'osm');
      expect(result.candidates.single.provenance.sourcePlaceId, 'osm:10');
    });
  });
}

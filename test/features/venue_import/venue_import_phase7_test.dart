import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/venue_import/domain/venue_discovery.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_discovery_pipeline.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_import_geo_config.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/noop_venue_discovery_provider.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/osm_venue_discovery_provider.dart';

void main() {
  group('Phase 7 geo + category config', () {
    test('Country → State → District tree for India / AP', () {
      final india = importCountryByCode('India');
      expect(india, isNotNull);
      expect(india!.states, isNotEmpty);
      final ap = importStateConfig('India', 'Andhra Pradesh');
      expect(ap, isNotNull);
      expect(ap!.districts.any((d) => d.name == 'Prakasam'), isTrue);
      expect(ap.districts.any((d) => d.name == kEntireState), isTrue);
      expect(
        importDistrictConfig('India', 'Andhra Pradesh', 'Prakasam')?.bbox,
        isNotNull,
      );
    });

    test('supports halls, hotels, resorts, institutes, meeting, sports, classrooms/events', () {
      final slugs = kDefaultImportCategories.map((c) => c.slug).toSet();
      expect(slugs.contains('function_hall'), isTrue);
      expect(slugs.contains('hotel'), isTrue);
      expect(slugs.contains('resort'), isTrue);
      expect(slugs.contains('institute'), isTrue);
      expect(slugs.contains('meeting_room'), isTrue);
      expect(slugs.contains('coworking_space'), isTrue);
      expect(slugs.contains('sports_ground'), isTrue);
      expect(slugs.contains('classroom'), isTrue);
      expect(slugs.contains('event_space'), isTrue);
    });

    test('category enable/disable via copyWith', () {
      final hotel = importCategoryBySlug('hotel')!;
      expect(hotel.isActive, isTrue);
      expect(hotel.copyWith(isActive: false).isActive, isFalse);
    });
  });

  group('Generalized OSM query builder', () {
    test('hotel tags use tourism=hotel and district bbox when available', () {
      const query = VenueDiscoveryQuery(
        country: 'India',
        state: 'Andhra Pradesh',
        district: 'Prakasam',
        categorySlug: 'hotel',
      );
      final ql = OsmVenueDiscoveryProvider.buildOverpassQuery(query);
      expect(ql.contains('tourism'), isTrue);
      expect(ql.contains('hotel'), isTrue);
      expect(ql.contains('15.2'), isTrue); // bbox south
      expect(ql.contains('area.searchArea'), isFalse);
    });

    test('name~= patterns and statewide area when Entire state', () {
      const query = VenueDiscoveryQuery(
        country: 'India',
        state: 'Telangana',
        district: kEntireState,
        categorySlug: 'function_hall',
        osmTags: [
          'amenity=events_venue',
          'name~=Function Hall|Mandapam',
        ],
      );
      final ql = OsmVenueDiscoveryProvider.buildOverpassQuery(query);
      expect(ql.contains('Telangana'), isTrue);
      expect(ql.contains('name"~"Function Hall|Mandapam"'), isTrue);
      expect(ql.contains('admin_level'), isTrue);
    });

    test('sports category resolves leisure tags from config', () {
      const query = VenueDiscoveryQuery(
        country: 'India',
        state: 'Karnataka',
        district: kEntireState,
        categorySlug: 'sports_ground',
      );
      final tags = OsmVenueDiscoveryProvider.resolveOsmTags(query);
      expect(tags.any((t) => t.contains('leisure=')), isTrue);
    });
  });

  group('Discovery pipeline with district', () {
    test('fills district from query when candidate blank', () async {
      final pipeline = VenueDiscoveryPipeline(
        MemoryVenueDiscoveryProvider(
          seed: [
            VenueDiscoveryCandidate(
              name: 'Coastal Resort',
              categorySlug: 'resort',
              latitude: 17.7,
              longitude: 83.3,
              provenance: VenueDiscoveryProvenance(
                sourceCode: VenueDiscoverySources.osm,
                sourcePlaceId: 'node/99',
                fetchedAt: DateTime.utc(2026, 8, 5),
              ),
            ),
          ],
        ),
      );
      final result = await pipeline.run(
        const VenueDiscoveryQuery(
          country: 'India',
          state: 'Andhra Pradesh',
          district: 'Visakhapatnam',
          categorySlug: 'resort',
        ),
      );
      expect(result.candidates.single.district, 'Visakhapatnam');
      expect(result.candidates.single.categorySlug, 'resort');
    });
  });
}

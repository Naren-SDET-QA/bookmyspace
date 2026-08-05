import 'package:bookmyspace/features/venue_import/domain/venue_discovery.dart';
import 'package:bookmyspace/features/venue_import/domain/venue_discovery_pipeline.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/noop_venue_discovery_provider.dart';
import 'package:bookmyspace/features/venue_import/infrastructure/osm_venue_discovery_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Andhra district bboxes configured for expansion', () {
    expect(OsmVenueDiscoveryProvider.andhraDistrictBboxes.containsKey('Prakasam'), isTrue);
    expect(OsmVenueDiscoveryProvider.andhraDistrictBboxes.containsKey('Guntur'), isTrue);
    expect(OsmVenueDiscoveryProvider.andhraDistrictBboxes.containsKey('Krishna'), isTrue);
    expect(OsmVenueDiscoveryProvider.andhraDistrictBboxes.containsKey('Visakhapatnam'), isTrue);
    expect(OsmVenueDiscoveryProvider.andhraDistrictBboxes.length, greaterThanOrEqualTo(4));
  });

  test('pipeline stages OSM-shaped candidates with provenance', () async {
    final seed = [
      VenueDiscoveryCandidate(
        name: 'Sri Lakshmi Function Hall',
        categorySlug: 'function_hall',
        latitude: 15.5,
        longitude: 80.05,
        city: 'Ongole',
        district: 'Prakasam',
        phone: '9876543210',
        provenance: VenueDiscoveryProvenance(
          sourceCode: VenueDiscoverySources.osm,
          sourcePlaceId: 'node/1',
          sourceUrl: 'https://www.openstreetmap.org/node/1',
          fetchedAt: DateTime.utc(2026, 8, 5),
        ),
      ),
      VenueDiscoveryCandidate(
        name: 'Sri Lakshmi Function Hall',
        categorySlug: 'function_hall',
        latitude: 15.5,
        longitude: 80.05,
        provenance: VenueDiscoveryProvenance(
          sourceCode: VenueDiscoverySources.osm,
          sourcePlaceId: 'node/1',
          fetchedAt: DateTime.utc(2026, 8, 5),
        ),
      ),
    ];
    final pipeline = VenueDiscoveryPipeline(MemoryVenueDiscoveryProvider(seed: seed));
    final result = await pipeline.run(
      const VenueDiscoveryQuery(
        country: 'India',
        state: 'Andhra Pradesh',
        categorySlug: 'function_hall',
      ),
    );
    expect(result.uniqueCount, 1);
    expect(result.duplicatesDropped, 1);
    expect(result.candidates.single.provenance.sourceCode, 'osm');
    expect(result.candidates.single.phone, '+919876543210');
  });
}

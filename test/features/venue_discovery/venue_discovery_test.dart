import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/venue_discovery/domain/venue_discovery.dart';

void main() {
  test('parses OSM elements without fabricating optional fields', () {
    final result = OverpassVenueParser.parse({
      'elements': [
        {
          'type': 'node',
          'id': 42,
          'lat': 12.3,
          'lon': 77.5,
          'tags': {'name': 'Hall', 'addr:city': 'Bengaluru', 'phone': '+1'},
        },
      ],
    }, sourceUrl: 'https://www.openstreetmap.org/node/42');
    expect(result.single.sourcePlaceId, 'node/42');
    expect(result.single.phone, '+1');
    expect(result.single.website, isNull);
  });

  test('deduplicates by source and source place id', () {
    final store = InMemoryVenueStagingStore();
    final venue = DiscoveredVenue(
      source: 'osm',
      sourcePlaceId: 'node/1',
      name: 'A',
      latitude: 1,
      longitude: 2,
    );
    expect(store.stage(venue), StageStatus.staged);
    expect(store.stage(venue), StageStatus.duplicate);
    expect(store.records, hasLength(1));
  });

  test('review transitions are controlled and auditable', () {
    final store = InMemoryVenueStagingStore();
    final venue = DiscoveredVenue(
      source: 'osm',
      sourcePlaceId: 'node/2',
      name: 'B',
      latitude: 1,
      longitude: 2,
    );
    store.stage(venue);
    expect(
      store.review('node/2', approved: true, actorId: 'admin'),
      ReviewStatus.approved,
    );
    expect(
      store.review('node/2', approved: false, actorId: 'admin'),
      ReviewStatus.invalidTransition,
    );
    expect(store.audit.single.actorId, 'admin');
  });

  test('claim allows one eligible owner only', () {
    final store = InMemoryVenueStagingStore();
    final venue = DiscoveredVenue(
      source: 'osm',
      sourcePlaceId: 'node/3',
      name: 'C',
      latitude: 1,
      longitude: 2,
    );
    store.stage(venue);
    store.review('node/3', approved: true, actorId: 'admin');
    store.publish('node/3', actorId: 'admin');
    expect(store.claim('node/3', 'owner-a'), ClaimStatus.claimed);
    expect(store.claim('node/3', 'owner-b'), ClaimStatus.alreadyClaimed);
  });
}

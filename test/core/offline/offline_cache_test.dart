import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/offline/offline_cache.dart';
import 'package:bookmyspace/core/offline/offline_store.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:bookmyspace/features/venues/domain/venue_repository.dart';
import 'package:bookmyspace/features/venues/infrastructure/caching_venue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _venue() => Venue.fromJson({
  'id': 'v1',
  'name': 'Sunrise Function Hall',
  'city': 'Hyderabad',
  'latitude': 17.4,
  'longitude': 78.4,
  'pricing_base_amount': 1000,
});

Booking _booking() => Booking(
  id: 'b1',
  bookingRef: 'BMS-1',
  venueId: 'v1',
  slotId: 's1',
  bookDate: DateTime(2026, 9, 1),
  startTime: '09:00:00',
  endTime: '10:00:00',
  status: BookingStatus.pending,
  amount: 100,
  taxAmount: 18,
  totalAmount: 118,
  venueName: 'Sunrise Function Hall',
);

void main() {
  test('venues and bookings round-trip through the offline cache', () async {
    final cache = OfflineCache(MemoryOfflineStore());
    await cache.saveVenues(OfflineCache.popularKey, [_venue()]);
    await cache.saveBookings(OfflineCache.bookingsKey, [_booking()]);

    final venues = await cache.loadVenues(OfflineCache.popularKey);
    final bookings = await cache.loadBookings(OfflineCache.bookingsKey);
    expect(venues, isNotNull);
    expect(venues!.single.name, 'Sunrise Function Hall');
    expect(bookings!.single.bookingRef, 'BMS-1');
    expect(bookings.single.venueName, 'Sunrise Function Hall');
  });

  test(
    'read-through returns live data and does not use cache while online',
    () async {
      final cache = OfflineCache(MemoryOfflineStore());
      await cache.saveVenues('k', [_venue()]);
      final live = Venue.fromJson({
        'id': 'v2',
        'name': 'Live Hall',
        'latitude': 1,
        'longitude': 2,
      });
      final result = await cache.readThroughVenues('k', () async => [live]);
      expect(result.single.name, 'Live Hall');
    },
  );

  test('read-through falls back to cache on network failure', () async {
    final cache = OfflineCache(MemoryOfflineStore());
    await cache.saveVenues('k', [_venue()]);
    final result = await cache.readThroughVenues(
      'k',
      () async => throw const NetworkException('offline'),
    );
    expect(result.single.name, 'Sunrise Function Hall');
  });

  test('read-through rethrows non-network failures', () async {
    final cache = OfflineCache(MemoryOfflineStore());
    await cache.saveVenues('k', [_venue()]);
    expect(
      () => cache.readThroughVenues(
        'k',
        () async => throw const ServerException('boom'),
      ),
      throwsA(isA<ServerException>()),
    );
  });

  test('read-through records whether the snapshot came from cache', () async {
    final cache = OfflineCache(MemoryOfflineStore());
    await cache.saveVenues('k', [_venue()]);
    await cache.readThroughVenues(
      'k',
      () async => throw const NetworkException('offline'),
    );
    expect(cache.servedFromCache, isTrue);
    await cache.readThroughVenues('k', () async => [_venue()]);
    expect(cache.servedFromCache, isFalse);
  });

  test('isOfflineWorthy treats fetch/host-lookup failures as offline', () {
    expect(isOfflineWorthy(const NetworkException('offline')), isTrue);
    expect(isOfflineWorthy(Exception('Failed host lookup')), isTrue);
    expect(isOfflineWorthy(Exception('Failed to fetch')), isTrue);
    expect(isOfflineWorthy(const ServerException('boom')), isFalse);
  });

  test('malformed venue JSON is treated as a cache miss and removed', () async {
    final store = MemoryOfflineStore({'bad': '{not-json'});
    final cache = OfflineCache(store);
    expect(await cache.loadVenues('bad'), isNull);
    expect(store.snapshot, isNot(contains('bad')));
  });

  test(
    'malformed booking JSON is treated as a cache miss and removed',
    () async {
      final store = MemoryOfflineStore({'bad': '{not-json'});
      final cache = OfflineCache(store);
      expect(await cache.loadBookings('bad'), isNull);
      expect(store.snapshot, isNot(contains('bad')));
    },
  );

  test(
    'caching venue repository serves search snapshots when the network fails',
    () async {
      final inner = _FailingSearchRepository();
      final cache = OfflineCache(MemoryOfflineStore());
      await cache.saveVenues(
        OfflineCache.searchKey(const VenueSearchQuery(query: 'hall')),
        [_venue()],
      );
      final repo = CachingVenueRepository(inner, cache);
      final result = await repo.search(const VenueSearchQuery(query: 'hall'));
      expect(result.single.id, 'v1');
    },
  );

  test('favorites cache keys are isolated per authenticated user', () {
    final cache = OfflineCache(MemoryOfflineStore());
    final first = CachingVenueRepository(
      _FailingSearchRepository(),
      cache,
      cacheScope: 'user-a',
    );
    final second = CachingVenueRepository(
      _FailingSearchRepository(),
      cache,
      cacheScope: 'user-b',
    );
    expect(first.cacheScope, isNot(second.cacheScope));
  });
}

class _FailingSearchRepository implements VenueRepository {
  @override
  Future<List<VenueCategory>> categories() async => const [];

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async => const [];

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async => const [];

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    throw const NetworkException('offline');
  }

  @override
  Future<Venue> venueById(String id) async => _venue();

  @override
  Future<List<String>> favoriteIds() async => const [];

  @override
  Future<List<Venue>> favorites() async => const [];

  @override
  Future<void> addFavorite(String venueId) async {}

  @override
  Future<void> removeFavorite(String venueId) async {}
}

import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_venue_repository.dart';

void main() {
  group('Venue', () {
    test('serializes and deserializes a rich row', () {
      final json = {
        'id': 'v1',
        'name': 'Sunrise Function Hall',
        'slug': 'sunrise-function-hall',
        'description': 'A hall',
        'city': 'Hyderabad',
        'state': 'Telangana',
        'latitude': 17.385,
        'longitude': 78.486,
        'capacity': 500,
        'pricing_base_amount': 35000,
        'tax_rate': 18,
        'avg_rating': 4.8,
        'rating_count': 120,
        'is_verified': true,
        'venue_categories': {
          'id': 'cat-1',
          'slug': 'function_hall',
          'name': 'Function Hall',
        },
        'venue_images': [
          {'id': 'i1', 'url': 'https://x/y.jpg', 'is_cover': true},
        ],
        'venue_facilities': [
          {'facility': 'Parking', 'is_available': true},
        ],
        'venue_operating_hours': [
          {'day_of_week': 0, 'opens_at': '09:00:00', 'closes_at': '23:00:00'},
        ],
      };

      final venue = Venue.fromJson(json);
      expect(venue.name, 'Sunrise Function Hall');
      expect(venue.category?.slug, 'function_hall');
      expect(venue.coverImageUrl, 'https://x/y.jpg');
      expect(venue.facilities, hasLength(1));
      expect(venue.operatingHours, hasLength(1));
      expect(venue.address, contains('Hyderabad'));
    });

    test('coverImageUrl picks the cover image first', () {
      const venue = Venue(
        id: 'v',
        name: 'V',
        latitude: 0,
        longitude: 0,
        images: [
          VenueImage(id: 'a', url: 'a.jpg'),
          VenueImage(id: 'b', url: 'b.jpg', isCover: true),
        ],
      );
      expect(venue.coverImageUrl, 'b.jpg');
    });

    test('coverImageUrl is empty with no images', () {
      const venue = Venue(id: 'v', name: 'V', latitude: 0, longitude: 0);
      expect(venue.coverImageUrl, isEmpty);
    });

    test('copyWith hydrates collections and distance', () {
      const venue = Venue(id: 'v', name: 'V', latitude: 0, longitude: 0);
      final hydrated = venue.copyWith(
        distanceKm: 3.2,
        images: const [VenueImage(id: 'i', url: 'u.jpg')],
      );
      expect(hydrated.distanceKm, 3.2);
      expect(hydrated.images, hasLength(1));
      expect(hydrated.name, 'V');
    });
  });

  group('VenueSearchQuery', () {
    test('hasFilters detects active filters', () {
      const empty = VenueSearchQuery();
      const filtered = VenueSearchQuery(query: 'hall');
      const byCategory = VenueSearchQuery(categorySlug: 'meeting_room');
      expect(empty.hasFilters, isFalse);
      expect(filtered.hasFilters, isTrue);
      expect(byCategory.hasFilters, isTrue);
    });

    test('copyWith clears optional filters with null', () {
      const q = VenueSearchQuery(categorySlug: 'meeting_room', query: 'x');
      final cleared = q.copyWith(categorySlug: () => null);
      expect(cleared.categorySlug, isNull);
      expect(cleared.query, 'x');
    });
  });

  group('MockVenueRepository', () {
    test('popularVenues returns sorted by rating count', () async {
      final repo = MockVenueRepository();
      final popular = await repo.popularVenues();
      expect(popular.first.id, 'v3'); // 214 ratings
      expect(popular.length, 3);
    });

    test('search filters by category and price', () async {
      final repo = MockVenueRepository();
      final results = await repo.search(
        const VenueSearchQuery(categorySlug: 'meeting_room'),
      );
      expect(results, hasLength(1));
      expect(results.first.id, 'v2');

      final priceResults = await repo.search(
        const VenueSearchQuery(minPrice: 10000),
      );
      expect(priceResults, hasLength(1));
      expect(priceResults.first.id, 'v1');
    });

    test('search sorts by price ascending', () async {
      final repo = MockVenueRepository();
      final results = await repo.search(
        const VenueSearchQuery(sortBy: VenueSortBy.priceAsc),
      );
      expect(results.first.id, 'v3');
      expect(results.last.id, 'v1');
    });

    test('favourites round-trip', () async {
      final repo = MockVenueRepository();
      await repo.addFavorite('v1');
      expect(await repo.favoriteIds(), ['v1']);
      expect(await repo.favorites(), hasLength(1));

      await repo.removeFavorite('v1');
      expect(await repo.favorites(), isEmpty);
    });

    test('surfaces failures', () async {
      final repo = MockVenueRepository()..failRequests = true;
      expect(repo.popularVenues(), throwsException);
      expect(repo.favorites(), throwsException);
    });
  });
}

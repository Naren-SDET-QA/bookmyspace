import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VenueSearchQuery.hasFilters', () {
    test('empty query has no filters', () {
      expect(const VenueSearchQuery().hasFilters, isFalse);
    });

    test('section id counts as a filter', () {
      expect(
        const VenueSearchQuery(sectionId: 'function_halls').hasFilters,
        isTrue,
      );
    });

    test('location fields count as filters', () {
      expect(
        const VenueSearchQuery(
          latitude: 17.44,
          longitude: 78.39,
          maxDistanceKm: 10,
        ).hasFilters,
        isTrue,
      );
    });

    test('section-specific fields count as filters', () {
      final queries = [
        const VenueSearchQuery(minCapacity: 200),
        VenueSearchQuery(date: DateTime(2026, 12, 25)),
        VenueSearchQuery(checkIn: DateTime(2026, 1, 1)),
        VenueSearchQuery(checkOut: DateTime(2026, 1, 3)),
        const VenueSearchQuery(roomType: 'double'),
        const VenueSearchQuery(minRating: 4.5),
        const VenueSearchQuery(gender: 'ladies'),
        const VenueSearchQuery(sharing: 'single'),
        const VenueSearchQuery(foodIncluded: true),
        const VenueSearchQuery(maxDeposit: 5000),
        const VenueSearchQuery(classType: 'coaching'),
        const VenueSearchQuery(mode: 'online'),
        const VenueSearchQuery(amenities: {'parking'}),
      ];
      for (final q in queries) {
        expect(q.hasFilters, isTrue, reason: '$q');
      }
    });
  });

  group('VenueSearchQuery.copyWith', () {
    test('copyWith clears nullable section-specific fields', () {
      const base = VenueSearchQuery(
        roomType: 'double',
        minRating: 4.5,
        gender: 'ladies',
        maxDeposit: 5000,
        minCapacity: 100,
        amenities: {'parking'},
      );
      final cleared = base.copyWith(
        roomType: () => null,
        minRating: () => null,
        gender: () => null,
        maxDeposit: () => null,
        minCapacity: () => null,
        amenities: const {},
      );
      expect(cleared.roomType, isNull);
      expect(cleared.minRating, isNull);
      expect(cleared.gender, isNull);
      expect(cleared.maxDeposit, isNull);
      expect(cleared.minCapacity, isNull);
      expect(cleared.amenities, isEmpty);
      expect(cleared.hasFilters, isFalse);
    });

    test('copyWith sets location fields', () {
      const base = VenueSearchQuery();
      final located = base.copyWith(
        latitude: () => 17.44,
        longitude: () => 78.39,
        maxDistanceKm: () => 25,
      );
      expect(located.hasLocation, isTrue);
      expect(located.latitude, 17.44);
      expect(located.maxDistanceKm, 25);
    });
  });

  group('VenueSearchQuery.hasLocation', () {
    test('true only when both coordinates are set', () {
      expect(
        const VenueSearchQuery(
          latitude: 17.44,
          longitude: 78.39,
        ).hasLocation,
        isTrue,
      );
      expect(const VenueSearchQuery(latitude: 17.44).hasLocation, isFalse);
      expect(const VenueSearchQuery().hasLocation, isFalse);
    });
  });
}
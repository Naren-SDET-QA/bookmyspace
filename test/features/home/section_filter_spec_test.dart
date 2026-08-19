import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

void main() {
  group('CustomerSectionCatalog.filterSpecs', () {
    test('halls expose date, guests, price and amenities filters', () {
      final specs = CustomerSectionCatalog.filterSpecs(
        CustomerSection.functionHalls,
      );
      final fields = specs.map((s) => s.field).toList();
      expect(fields, containsAll([
        SectionFilterField.date,
        SectionFilterField.guests,
        SectionFilterField.priceRange,
        SectionFilterField.amenities,
      ]));
      expect(
        specs
            .firstWhere((s) => s.field == SectionFilterField.amenities)
            .options,
        containsAll(['parking', 'catering', 'ac', 'power_backup']),
      );
      final amenityIds = CustomerSectionCatalog.amenityFilters(
        CustomerSection.functionHalls,
      )
          .map((a) => a.id)
          .toList();
      expect(
        specs
            .firstWhere((s) => s.field == SectionFilterField.amenities)
            .options
            .every(amenityIds.contains),
        isTrue,
      );
    });

    test('stays expose check-in/out, room type, rating and price', () {
      final fields = CustomerSectionCatalog.filterSpecs(
        CustomerSection.lodgeRooms,
      ).map((s) => s.field).toList();
      expect(fields, containsAll([
        SectionFilterField.checkInOut,
        SectionFilterField.roomType,
        SectionFilterField.minRating,
        SectionFilterField.priceRange,
      ]));
    });

    test('PG exposes gender, sharing, food, rent and deposit', () {
      final fields = CustomerSectionCatalog.filterSpecs(
        CustomerSection.pgHostels,
      ).map((s) => s.field).toList();
      expect(fields, containsAll([
        SectionFilterField.gender,
        SectionFilterField.sharing,
        SectionFilterField.food,
        SectionFilterField.priceRange,
        SectionFilterField.deposit,
      ]));
    });

    test('institutes expose class type, mode and fee', () {
      final fields = CustomerSectionCatalog.filterSpecs(
        CustomerSection.institutesClasses,
      ).map((s) => s.field).toList();
      expect(fields, containsAll([
        SectionFilterField.classType,
        SectionFilterField.mode,
        SectionFilterField.priceRange,
      ]));
      expect(
        CustomerSectionCatalog.filterSpecs(
          CustomerSection.institutesClasses,
        )
            .firstWhere((s) => s.field == SectionFilterField.mode)
            .options,
        containsAll(['online', 'offline', 'hybrid']),
      );
    });
  });

  group('CustomerSectionCatalog.matchesFilters', () {
    const venues = MockVenueRepository.defaultVenues;
    Venue byName(String name) => venues.firstWhere((v) => v.name == name);

    test('halls guests filter uses capacity', () {
      final hall = byName('Sunrise Function Hall');
      expect(
        CustomerSectionCatalog.matchesFilters(
          hall,
          const VenueSearchQuery(minCapacity: 200),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          hall,
          const VenueSearchQuery(minCapacity: 600),
        ),
        isFalse,
      );
    });

    test('stays rating filter uses avg rating', () {
      final lodge = byName('Crown Lodge Rooms');
      expect(
        CustomerSectionCatalog.matchesFilters(
          lodge,
          const VenueSearchQuery(minRating: 4.5),
        ),
        isFalse,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Sunrise Function Hall'),
          const VenueSearchQuery(minRating: 4.5),
        ),
        isTrue,
      );
    });

    test('stays room type filter matches keyword haystack', () {
      final lodge = byName('Crown Lodge Rooms');
      expect(
        CustomerSectionCatalog.matchesFilters(
          lodge,
          const VenueSearchQuery(roomType: 'double'),
        ),
        isFalse,
      );
      const suite = Venue(
        id: 'suite',
        name: 'Grand Suite Stay',
        description: 'Deluxe double room with city view',
        latitude: 0,
        longitude: 0,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          suite,
          const VenueSearchQuery(roomType: 'double'),
        ),
        isTrue,
      );
    });

    test('PG gender filter keeps ladies-only listings', () {
      final ladies = byName('Starlight Ladies PG');
      expect(
        CustomerSectionCatalog.matchesFilters(
          ladies,
          const VenueSearchQuery(gender: 'ladies'),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          ladies,
          const VenueSearchQuery(gender: 'gents'),
        ),
        isFalse,
      );
    });

    test('PG sharing filter matches single / double / triple', () {
      const shared = Venue(
        id: 'shared',
        name: 'Sunrise Gents PG',
        description: 'Single and double sharing rooms with food',
        latitude: 0,
        longitude: 0,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          shared,
          const VenueSearchQuery(sharing: 'single'),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          shared,
          const VenueSearchQuery(sharing: 'triple'),
        ),
        isFalse,
      );
    });

    test('PG food filter requires food keywords', () {
      final ladies = byName('Starlight Ladies PG');
      expect(
        CustomerSectionCatalog.matchesFilters(
          ladies,
          const VenueSearchQuery(foodIncluded: true),
        ),
        isTrue,
      );
      final hall = byName('Sunrise Function Hall');
      expect(
        CustomerSectionCatalog.matchesFilters(
          hall,
          const VenueSearchQuery(foodIncluded: true),
        ),
        isFalse,
      );
    });

    test('PG deposit filter requires a disclosed deposit', () {
      const withDeposit = Venue(
        id: 'dep',
        name: 'Green Valley PG',
        description: 'Gents PG',
        latitude: 0,
        longitude: 0,
        facilities: [VenueFacility(facility: 'Security Deposit ₹5000')],
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          withDeposit,
          const VenueSearchQuery(maxDeposit: 5000),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Starlight Ladies PG'),
          const VenueSearchQuery(maxDeposit: 5000),
        ),
        isFalse,
      );
    });

    test('institutes mode and class type match keywords', () {
      final academy = byName('Apex Sports Academy');
      expect(
        CustomerSectionCatalog.matchesFilters(
          academy,
          const VenueSearchQuery(classType: 'sports'),
        ),
        isTrue,
      );
      const offlineAcademy = Venue(
        id: 'off',
        name: 'Apex Sports Academy',
        description: 'Offline badminton coaching and sports turf listings',
        latitude: 0,
        longitude: 0,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          offlineAcademy,
          const VenueSearchQuery(mode: 'offline'),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          offlineAcademy,
          const VenueSearchQuery(mode: 'online'),
        ),
        isFalse,
      );
    });

    test('amenities filter reuses the keyword haystack', () {
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Sunrise Function Hall'),
          const VenueSearchQuery(amenities: {'parking', 'ac'}),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Crown Lodge Rooms'),
          const VenueSearchQuery(amenities: {'parking'}),
        ),
        isFalse,
      );
    });

    test('price range filter applies to every section', () {
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Crown Lodge Rooms'),
          const VenueSearchQuery(minPrice: 1000, maxPrice: 3000),
        ),
        isTrue,
      );
      expect(
        CustomerSectionCatalog.matchesFilters(
          byName('Sunrise Function Hall'),
          const VenueSearchQuery(maxPrice: 10000),
        ),
        isFalse,
      );
    });

    test('empty query matches everything', () {
      for (final v in venues) {
        expect(
          CustomerSectionCatalog.matchesFilters(v, const VenueSearchQuery()),
          isTrue,
          reason: v.name,
        );
      }
    });
  });
}
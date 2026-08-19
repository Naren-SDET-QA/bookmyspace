import 'dart:io';
import 'dart:typed_data';

import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/owner_venues/domain/owner_listing_draft.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';
import 'mock_owner_venue_repository.dart';

void main() {
  test('owner categories never include the customer All chip', () {
    for (final section in CustomerSection.values) {
      expect(
        CustomerSectionCatalog.ownerCategories(
          section,
        ).any((c) => c.id == 'all'),
        isFalse,
      );
    }
  });

  test('persistable slugs stay inside their section', () {
    expect(
      CustomerSectionCatalog.fromAny(
        CustomerSectionCatalog.persistableCategorySlug(
          CustomerSection.functionHalls,
          'banquet_hall',
        ),
      ),
      CustomerSection.functionHalls,
    );
    expect(
      CustomerSectionCatalog.fromAny(
        CustomerSectionCatalog.persistableCategorySlug(
          CustomerSection.lodgeRooms,
          'guest_house',
        ),
      ),
      CustomerSection.lodgeRooms,
    );
    expect(
      CustomerSectionCatalog.fromAny(
        CustomerSectionCatalog.persistableCategorySlug(
          CustomerSection.pgHostels,
          'ladies_pg',
        ),
      ),
      CustomerSection.pgHostels,
    );
    expect(
      CustomerSectionCatalog.fromAny(
        CustomerSectionCatalog.persistableCategorySlug(
          CustomerSection.institutesClasses,
          'dance_academy',
        ),
      ),
      CustomerSection.institutesClasses,
    );
  });

  test('resolveDbCategory never returns a slug from another section', () async {
    final repo = MockVenueRepository();
    final cats = await repo.categories();
    final hotel = CustomerSectionCatalog.resolveDbCategory(
      dbCategories: cats,
      section: CustomerSection.lodgeRooms,
      catalogCategoryId: 'function_hall',
    );
    expect(hotel.slug, 'hotel_stay');
    expect(
      CustomerSectionCatalog.fromAny(hotel.slug),
      CustomerSection.lodgeRooms,
    );

    expect(
      () => CustomerSectionCatalog.resolveDbCategory(
        dbCategories: [
          const VenueCategory(
            id: 'only-hall',
            slug: 'function_hall',
            name: 'Function Hall',
          ),
        ],
        section: CustomerSection.lodgeRooms,
        catalogCategoryId: 'hotel',
      ),
      throwsStateError,
    );
  });

  test('save listing stores photos, location and unpublished draft', () async {
    final repo = MockOwnerVenueRepository();
    final venue = await repo.saveListing(
      draft: const OwnerListingDraft(
        name: 'Starlight Ladies PG',
        section: CustomerSection.pgHostels,
        catalogCategoryId: 'ladies_pg',
        categoryId: 'cat-pg',
        description: 'Ladies PG near campus',
        city: 'Hyderabad',
        state: 'Telangana',
        addressLine1: 'Madhapur',
        latitude: 17.45,
        longitude: 78.39,
        capacity: 12,
        pricingBaseAmount: 9000,
        photos: [
          OwnerListingPhoto(remoteUrl: 'https://example.com/cover.jpg'),
          OwnerListingPhoto(remoteUrl: 'https://example.com/room.jpg'),
        ],
        facilities: ['Ladies PG', 'Wi-Fi'],
      ),
    );

    expect(venue.isActive, isFalse);
    expect(venue.images, hasLength(2));
    expect(venue.images.first.isCover, isTrue);
    expect(venue.latitude, 17.45);
    expect(
      CustomerSectionCatalog.sectionForVenue(venue),
      CustomerSection.pgHostels,
    );
    expect(
      CustomerSectionCatalog.sectionForVenue(venue),
      isNot(CustomerSection.functionHalls),
    );
  });

  test('publish and photo reorder stay on the same listing', () async {
    final repo = MockOwnerVenueRepository();
    final created = await repo.saveListing(
      draft: const OwnerListingDraft(
        name: 'Crown Lodge',
        section: CustomerSection.lodgeRooms,
        catalogCategoryId: 'lodge',
        categoryId: 'cat-hotel',
        description: 'Budget lodge',
        city: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.4,
        longitude: 78.5,
        capacity: 8,
        pricingBaseAmount: 1500,
        photos: [
          OwnerListingPhoto(remoteUrl: 'https://example.com/a.jpg'),
          OwnerListingPhoto(remoteUrl: 'https://example.com/b.jpg'),
        ],
      ),
    );

    await repo.replaceImages(created.id, [
      'https://example.com/b.jpg',
      'https://example.com/a.jpg',
    ]);
    final published = await repo.setPublished(created.id, true);
    expect(published.isActive, isTrue);
    expect(published.images.first.url, 'https://example.com/b.jpg');
    expect(published.images.first.isCover, isTrue);
  });

  test('delete listing removes it from the owner list', () async {
    final repo = MockOwnerVenueRepository();
    final created = await repo.saveListing(
      draft: const OwnerListingDraft(
        name: 'Temp Hall',
        section: CustomerSection.functionHalls,
        catalogCategoryId: 'marriage_hall',
        categoryId: 'cat-mh',
        description: 'Hall to delete',
        city: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.4,
        longitude: 78.5,
        capacity: 200,
        pricingBaseAmount: 20000,
      ),
    );
    expect(repo.venues, isNotEmpty);
    await repo.deleteVenue(created.id);
    expect(repo.venues.where((v) => v.id == created.id), isEmpty);
  });

  test(
    'lodge and pg map onto 0002 meeting_room without leaving their section',
    () {
      const baseOnly = [
        VenueCategory(id: 'fh', slug: 'function_hall', name: 'Function Hall'),
        VenueCategory(id: 'mr', slug: 'meeting_room', name: 'Meeting Room'),
        VenueCategory(id: 'sg', slug: 'sports_ground', name: 'Sports Ground'),
      ];
      final lodgeCat = CustomerSectionCatalog.resolveDbCategory(
        dbCategories: baseOnly,
        section: CustomerSection.lodgeRooms,
        catalogCategoryId: 'hotel',
      );
      expect(lodgeCat.slug, 'meeting_room');
      expect(CustomerSectionCatalog.fromAny(lodgeCat.slug), isNull);

      const lodge = Venue(
        id: 'l1',
        name: 'Crown Lodge',
        latitude: 17.4,
        longitude: 78.5,
        category: VenueCategory(
          id: 'mr',
          slug: 'meeting_room',
          name: 'Meeting Room',
        ),
        facilities: [
          VenueFacility(facility: 'Lodge'),
          VenueFacility(facility: 'Lodge / Rooms'),
        ],
      );
      expect(
        CustomerSectionCatalog.sectionForVenue(lodge),
        CustomerSection.lodgeRooms,
      );
      expect(
        CustomerSectionCatalog.sectionForVenue(lodge),
        isNot(CustomerSection.functionHalls),
      );

      final pgCat = CustomerSectionCatalog.resolveDbCategory(
        dbCategories: baseOnly,
        section: CustomerSection.pgHostels,
        catalogCategoryId: 'ladies_pg',
      );
      expect(pgCat.slug, 'meeting_room');
      const pg = Venue(
        id: 'p1',
        name: 'Starlight Ladies PG',
        latitude: 17.4,
        longitude: 78.5,
        category: VenueCategory(
          id: 'mr',
          slug: 'meeting_room',
          name: 'Meeting Room',
        ),
        facilities: [
          VenueFacility(facility: 'Ladies PG'),
          VenueFacility(facility: 'PG / Hostels'),
        ],
      );
      expect(
        CustomerSectionCatalog.sectionForVenue(pg),
        CustomerSection.pgHostels,
      );

      const boardroom = Venue(
        id: 'b1',
        name: 'The Boardroom',
        description: 'Modern meeting rooms for teams.',
        latitude: 17.4,
        longitude: 78.5,
        category: VenueCategory(
          id: 'mr',
          slug: 'meeting_room',
          name: 'Meeting Room',
        ),
      );
      expect(CustomerSectionCatalog.sectionForVenue(boardroom), isNull);

      const hall = Venue(
        id: 'h1',
        name: 'Royal Grand',
        description: 'Hotel-style luxury wedding hall',
        latitude: 17.4,
        longitude: 78.5,
        category: VenueCategory(
          id: 'fh',
          slug: 'function_hall',
          name: 'Function Hall',
        ),
      );
      expect(
        CustomerSectionCatalog.sectionForVenue(hall),
        CustomerSection.functionHalls,
      );
    },
  );

  test('lodge and pg persistable slugs live in migration 0019', () {
    final sql = File(
      'supabase/migrations/0019_owner_listing_categories_and_photos.sql',
    ).readAsStringSync();
    expect(sql.contains("'hotel_stay'"), isTrue);
    expect(sql.contains("'pg_coliving'"), isTrue);
    expect(sql.contains("'ladies_pg'"), isTrue);
    expect(sql.contains("'lodge'"), isTrue);
    expect(sql.contains('venue-images'), isTrue);
  });

  test('local photo bytes are stored as uploaded gallery urls', () async {
    final repo = MockOwnerVenueRepository();
    final venue = await repo.saveListing(
      draft: OwnerListingDraft(
        name: 'Sunrise Hall',
        section: CustomerSection.functionHalls,
        catalogCategoryId: 'marriage_hall',
        categoryId: 'cat-mh',
        description: 'Hall with real photos',
        city: 'Hyderabad',
        state: 'Telangana',
        latitude: 17.4,
        longitude: 78.5,
        capacity: 200,
        pricingBaseAmount: 20000,
        photos: [
          OwnerListingPhoto(
            bytes: Uint8List.fromList(List<int>.filled(32, 7)),
            fileName: 'hall.jpg',
            contentType: 'image/jpeg',
          ),
        ],
      ),
    );
    expect(venue.images, hasLength(1));
    expect(venue.images.single.url, 'https://example.com/uploads/hall.jpg');
    expect(venue.images.single.isCover, isTrue);
  });

  test('owner listing photo limit is six', () {
    expect(OwnerListingDraft.maxPhotos, 6);
    final draft = OwnerListingDraft(
      name: 'Too many photos',
      section: CustomerSection.functionHalls,
      catalogCategoryId: 'marriage_hall',
      categoryId: 'cat-mh',
      description: 'Listing',
      city: 'Hyderabad',
      state: 'Telangana',
      latitude: 17.4,
      longitude: 78.5,
      capacity: 100,
      pricingBaseAmount: 10000,
      photos: List.generate(
        OwnerListingDraft.maxPhotos + 1,
        (_) => const OwnerListingPhoto(remoteUrl: 'https://example.com/a.jpg'),
      ),
    );
    expect(draft.validate, throwsStateError);
  });

  test('institute listings stay advertising-only', () {
    expect(CustomerSection.institutesClasses.isBookable, isFalse);
    const venue = Venue(
      id: 'i1',
      name: 'CodeLab',
      latitude: 17.4,
      longitude: 78.5,
      category: VenueCategory(id: 'c', slug: 'sports_ground', name: 'Sports'),
    );
    expect(
      CustomerSectionCatalog.sectionForVenue(venue),
      CustomerSection.institutesClasses,
    );
    expect(
      CustomerSectionCatalog.bookingCtaLabel(CustomerSection.institutesClasses),
      'Enquire',
    );
  });
}

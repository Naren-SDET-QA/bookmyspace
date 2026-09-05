import 'package:bookmyspace/features/search/domain/ai_search_intent.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/category_discovery.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search filter categories use visible database configuration', () {
    final categories = [
      const CategoryConfiguration(
        id: 'hidden',
        slug: 'hidden_future',
        name: 'Hidden Future',
        sectionId: 'function_halls',
        searchable: false,
      ),
      const CategoryConfiguration(
        id: 'unknown',
        slug: 'temple_booking',
        name: 'Temple Booking',
        sectionId: 'function_halls',
        sortOrder: 1,
      ),
    ];

    final result = CategoryDiscovery.searchFilterCategories(
      categories,
      sectionId: 'function_halls',
    );

    expect(result.map((item) => item.slug), ['temple_booking']);
  });

  test('category configuration is driven by metadata, not slug switches', () {
    const category = VenueCategory(
      id: '1',
      slug: 'temple',
      name: 'Temple',
      metadata: {
        'section': 'function_halls',
        'bookable': true,
        'booking_mode': 'owner_approval',
        'customer_action_label': 'Request Slot',
        'aliases': ['mandir', 'devasthanam'],
        'ai_aliases': ['temple', 'mandir'],
        'localized_names': {'en': 'Temple', 'hi': 'मंदिर', 'te': 'గుడి'},
        'media_configuration': 'images',
      },
    );
    final config = CategoryConfiguration.fromCategory(category);
    expect(config.sectionId, 'function_halls');
    expect(config.bookable, isTrue);
    expect(config.customerAction, 'Request Slot');
    expect(config.localizedName('hi'), 'मंदिर');
    expect(config.localizedName('fr'), 'Temple');
    expect(config.allAliases, contains('mandir'));
  });

  test('category configuration reads database section_id metadata', () {
    const category = VenueCategory(
      id: '2',
      slug: 'student_hostel',
      name: 'Student Hostel',
      metadata: {'section_id': 'lodge_rooms', 'section_sort_order': 10},
    );

    final config = CategoryConfiguration.fromCategory(category);

    expect(config.sectionId, 'lodge_rooms');
    expect(config.sortOrder, 10);
  });

  test(
    'alias index matches multilingual tokens without per-category switches',
    () {
      final index = CategoryAliasIndex([
        const CategoryConfiguration(
          id: '1',
          slug: 'exhibition_hall',
          name: 'Exhibition Hall',
          sectionId: 'function_halls',
          aliases: ['expo', 'trade show'],
          aiAliases: ['exhibition'],
        ),
        const CategoryConfiguration(
          id: '2',
          slug: 'ladies_pg',
          name: 'Ladies PG',
          sectionId: 'pg_hostels',
          aliases: ['ladies pg'],
        ),
      ]);
      expect(index.match('expo in Hyderabad')?.slug, 'exhibition_hall');
      expect(index.match('ladies pg near me')?.sectionId, 'pg_hostels');
      expect(index.match('unrelated query'), isNull);
    },
  );

  test('AI search uses alias index when provided', () {
    final index = CategoryAliasIndex(const [
      CategoryConfiguration(
        id: '1',
        slug: 'temple',
        name: 'Temple',
        sectionId: 'function_halls',
        aiAliases: ['mandir', 'temple'],
      ),
    ]);
    final intent = AiSearchIntent.parse('mandir in Guntur', aliases: index);
    expect(intent.categorySlug, 'temple');
    expect(intent.section?.id, 'function_halls');
  });

  test(
    'sports court terminology resolves to the authoritative sports_ground category',
    () {
      final index = CategoryAliasIndex(const [
        CategoryConfiguration(
          id: 'sports-ground',
          slug: 'sports_ground',
          name: 'Sports Ground',
          sectionId: 'institutes_classes',
          aiAliases: ['sports ground', 'sports court'],
        ),
      ]);
      expect(index.match('book a sports court')?.slug, 'sports_ground');
    },
  );

  test('venue image media kind defaults to image for future video', () {
    final image = VenueImage.fromJson({
      'id': 'i1',
      'url': 'https://example.com/a.jpg',
    });
    expect(image.mediaKind, 'image');
    expect(image.isImage, isTrue);
    final video = VenueImage.fromJson({
      'id': 'i2',
      'url': 'https://example.com/a.mp4',
      'media_kind': 'video',
    });
    expect(video.isImage, isFalse);
  });
}

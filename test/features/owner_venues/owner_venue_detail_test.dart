import 'package:bookmyspace/features/owner_venues/domain/owner_venue_repository.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const venueRow = <String, dynamic>{
    'id': 'venue-1',
    'name': 'Sunrise Function Hall',
    'city': 'Hyderabad',
    'state': 'Telangana',
    'capacity': 500,
    'pricing_base_amount': 45000,
    'latitude': 17.385,
    'longitude': 78.486,
    'is_active': true,
    'description': 'A spacious hall',
    'venue_categories': <String, dynamic>{
      'id': 'cat-1',
      'slug': 'function_hall',
      'name': 'Function Hall',
      'icon': '🏛️',
    },
  };

  const images = <dynamic>[
    <String, dynamic>{'id': 'img-1', 'url': 'https://example.com/a.jpg'},
  ];
  const facilities = <dynamic>[
    <String, dynamic>{'id': 'f-1', 'facility': 'Parking', 'is_available': true},
  ];

  Map<String, dynamic> detailJson({required Map<String, dynamic> venue}) => {
        'venue': venue,
        'images': images,
        'facilities': facilities,
      };

  test('parses flat venue row with nested venue_categories (current RPC)', () {
    final detail = OwnerVenueDetail.fromJson(detailJson(venue: venueRow));

    expect(detail.venue.id, 'venue-1');
    expect(detail.venue.name, 'Sunrise Function Hall');
    expect(detail.venue.city, 'Hyderabad');
    expect(detail.venue.capacity, 500);
    expect(detail.venue.pricingBaseAmount, 45000);
    expect(detail.venue.category?.slug, 'function_hall');
    expect(detail.venue.category?.name, 'Function Hall');
    expect(detail.images, hasLength(1));
    expect(detail.images.first.url, 'https://example.com/a.jpg');
    expect(detail.facilities, hasLength(1));
    expect(detail.facilities.first.facility, 'Parking');
  });

  test('tolerates legacy wrapped shape {venue: {...}, venue_categories: {...}}',
      () {
    final wrapped = detailJson(venue: {
      'venue': Map<String, dynamic>.from(venueRow)..remove('venue_categories'),
      'venue_categories': venueRow['venue_categories'],
    });

    final detail = OwnerVenueDetail.fromJson(wrapped);

    expect(detail.venue.id, 'venue-1');
    expect(detail.venue.name, 'Sunrise Function Hall');
    expect(detail.venue.category?.name, 'Function Hall');
    expect(detail.images, hasLength(1));
  });

  test('missing venue falls back to an empty venue without throwing', () {
    final detail = OwnerVenueDetail.fromJson(<String, dynamic>{'images': <dynamic>[], 'facilities': <dynamic>[]});

    expect(detail.venue.id, '');
    expect(detail.images, isEmpty);
    expect(detail.facilities, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

void main() {
  test('dynamic category controls round-trip through metadata', () {
    final category = CategoryConfiguration.fromCategory(
      VenueCategory.fromJson({
        'id': 'dynamic-id',
        'slug': 'test_category',
        'name': 'Test Category',
        'icon': '',
        'metadata': {
          'active': true,
          'searchable': false,
          'bookable': true,
          'availability_enabled': false,
          'offers_enabled': false,
          'payments_enabled': false,
          'location_enabled': false,
        },
      }),
    );

    expect(category.visible, isTrue);
    expect(category.searchable, isFalse);
    expect(category.bookable, isTrue);
    expect(category.availabilityEnabled, isFalse);
    expect(category.offerVisible, isFalse);
    expect(category.paymentsEnabled, isFalse);
    expect(category.locationEnabled, isFalse);
    expect(category.toMetadata(), containsPair('availability_enabled', false));
    expect(category.toMetadata(), containsPair('payments_enabled', false));
    expect(category.toMetadata(), containsPair('location_enabled', false));
  });

  test('missing capability controls fail closed', () {
    final category = CategoryConfiguration.fromCategory(
      VenueCategory.fromJson({
        'id': 'future-id',
        'slug': 'future_category',
        'name': 'Future Category',
        'metadata': <String, dynamic>{'active': true},
      }),
    );

    expect(category.availabilityEnabled, isFalse);
    expect(category.paymentsEnabled, isFalse);
    expect(category.locationEnabled, isFalse);
  });
}

import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing registration metadata uses safe family defaults', () {
    CategoryConfiguration config(String slug) =>
        CategoryConfiguration.fromCategory(VenueCategory(
          id: slug,
          slug: slug,
          name: slug,
          metadata: const {},
        ));

    expect(config('function_hall').registrationRequired, isFalse);
    expect(config('hotel_stay').registrationRequired, isFalse);
    expect(config('pg_coliving').registrationRequired, isTrue);
    expect(config('pg_coliving').kycRequired, isTrue);
    expect(config('institute').registrationRequired, isTrue);
    expect(config('institute').kycRequired, isFalse);
  });

  test('explicit metadata overrides safe family defaults', () {
    final config = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: 'pg',
        slug: 'pg_coliving',
        name: 'PG',
        metadata: {
          'registration_required': false,
          'kyc_required': false,
          'registration_required_fields': ['custom_field'],
          'registration_optional_fields': ['notes'],
        },
      ),
    );
    expect(config.registrationRequired, isFalse);
    expect(config.kycRequired, isFalse);
    expect(config.registrationRequiredFields, ['custom_field']);
    expect(config.registrationOptionalFields, ['notes']);
  });
}

import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/listing_field_requirements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('falls back to default required fields when metadata is empty', () {
    final requirements = ListingFieldRequirements.from(null);
    expect(requirements.requiredKeys, ListingFieldRequirements.defaultRequired);
    expect(
      requirements.missing(
        name: 'Hall',
        city: 'Guntur',
        description: '',
        address: '',
        locationId: 'loc1',
        capacity: 200,
        price: 25000,
        photoCount: 0,
        amenityCount: 0,
      ),
      isEmpty,
    );
  });

  test('uses category metadata keys without slug switches', () {
    const config = CategoryConfiguration(
      id: '1',
      slug: 'temple',
      name: 'Temple',
      requiredFields: ['name', 'photos', 'capacity'],
      optionalFields: ['amenities'],
    );
    final requirements = ListingFieldRequirements.from(config);
    expect(
      requirements.missing(
        name: 'Sri Temple',
        city: 'Guntur',
        description: 'x',
        address: 'y',
        locationId: 'loc1',
        capacity: 50,
        price: 0,
        photoCount: 0,
        amenityCount: 0,
      ),
      ['photos'],
    );
  });

  test('unknown metadata keys never invent database columns', () {
    const config = CategoryConfiguration(
      id: '1',
      slug: 'hall',
      name: 'Hall',
      requiredFields: ['name', 'kyc_document'],
    );
    final missing = ListingFieldRequirements.from(config).missing(
      name: 'Hall',
      city: '',
      description: '',
      address: '',
      locationId: null,
      capacity: null,
      price: null,
      photoCount: 0,
      amenityCount: 0,
    );
    expect(missing, isEmpty);
  });
}

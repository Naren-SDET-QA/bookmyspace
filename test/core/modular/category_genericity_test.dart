import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown database categories continue working without new enums', () {
    expect(FeatureId.values.contains(FeatureId.functionHall), isTrue);
    final names = FeatureId.values.map((id) => id.name).toList();
    expect(names, isNot(contains('hotelCategory')));
    expect(names, isNot(contains('pgCategory')));
    expect(names, isNot(contains('templeCategory')));

    final config = CategoryConfiguration.fromCategory(
      const VenueCategory(
        id: 'new',
        slug: 'floating_pavilion',
        name: 'Floating Pavilion',
        metadata: {
          'section': 'function_halls',
          'bookable': true,
          'customer_action_label': 'Request Slot',
        },
      ),
    );
    expect(config.slug, 'floating_pavilion');
    expect(config.bookable, isTrue);
    expect(config.customerAction, 'Request Slot');
  });
}

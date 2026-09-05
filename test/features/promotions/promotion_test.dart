import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/promotions/domain/promotion.dart';

void main() {
  final category = DateTime(2026, 8, 26, 10);

  test('filters active date windows and preserves priority data', () {
    final promotion = Promotion(
      id: 'p1',
      title: 'Weekend',
      active: true,
      startAt: DateTime(2026, 8, 26),
      endAt: DateTime(2026, 8, 27),
      priority: 10,
    );
    expect(promotion.isVisibleAt(category), isTrue);
    expect(promotion.priority, 10);
    expect(promotion.isVisibleAt(DateTime(2026, 8, 28)), isFalse);
  });

  test('supports global, category and venue targeting', () {
    expect(const Promotion(id: 'g', title: 'Global').targets(), isTrue);
    expect(
      const Promotion(id: 'c', title: 'Hotel', categoryIds: ['hotel'])
          .targets(categoryId: 'hotel'),
      isTrue,
    );
    expect(
      const Promotion(id: 'v', title: 'Venue', venueIds: ['v1'])
          .targets(venueId: 'v1'),
      isTrue,
    );
  });

  test('parses normalized targeting and does not calculate prices', () {
    final promotion = Promotion.fromJson({
      'id': 'p1',
      'title': '20% off',
      'offer_type': 'percentage_discount',
      'discount_type': 'percentage',
      'discount_value': 20,
      'promotion_categories': [
        {'category_id': 'hotel'},
      ],
      'promotion_venues': [
        {'venue_id': 'v1'},
      ],
    });
    expect(promotion.categoryIds, ['hotel']);
    expect(promotion.venueIds, ['v1']);
    expect(promotion.discountValue, 20);
  });
}

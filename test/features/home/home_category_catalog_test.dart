import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/home/domain/home_category_catalog.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';

void main() {
  CategoryConfiguration category({
    required String id,
    required String name,
    required int order,
    String section = '',
    bool homeVisible = true,
  }) => CategoryConfiguration(
    id: id,
    slug: id,
    name: name,
    sectionId: section,
    sortOrder: order,
    homeVisible: homeVisible,
  );

  test('uses configured display order and preserves unknown categories', () {
    final result = HomeCategoryCatalog.effective(
      configurations: [
        category(id: 'co_working', name: 'Co-working', order: 3),
        category(
          id: 'function_hall',
          name: 'Function Halls',
          order: 1,
          section: 'function_halls',
        ),
        category(id: 'hotel', name: 'Hotels', order: 2, section: 'lodge_rooms'),
      ],
      globallyVisible: {'function_halls', 'lodge_rooms', 'co_working'},
      customerEnabled: {'function_hall', 'hotel', 'co_working'},
    );

    expect(result.map((item) => item.id), [
      'function_hall',
      'hotel',
      'co_working',
    ]);
    expect(result.last.isGeneric, isTrue);
  });

  test('hidden categories do not leave layout entries', () {
    final result = HomeCategoryCatalog.effective(
      configurations: [
        category(id: 'hotel', name: 'Hotels', order: 1, homeVisible: false),
        category(id: 'pg', name: 'PG', order: 2),
      ],
      globallyVisible: {'hotel', 'pg'},
      customerEnabled: {'hotel', 'pg'},
    );

    expect(result.map((item) => item.id), ['pg']);
  });

  test('customer preference can enable a configured section group', () {
    final result = HomeCategoryCatalog.effective(
      configurations: [
        category(id: 'hotel', name: 'Hotel', order: 1, section: 'lodge_rooms'),
      ],
      globallyVisible: {'lodge_rooms'},
      customerEnabled: {'lodge_rooms'},
    );

    expect(result.map((item) => item.id), ['hotel']);
  });

  test('empty effective configuration returns no fake categories', () {
    final result = HomeCategoryCatalog.effective(
      configurations: [category(id: 'hotel', name: 'Hotels', order: 1)],
      globallyVisible: const {},
      customerEnabled: const {},
    );

    expect(result, isEmpty);
  });
}

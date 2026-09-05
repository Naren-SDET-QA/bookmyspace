import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/home/domain/bookmyspace_module.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';

void main() {
  CategoryConfiguration config(String id, int order, {String section = ''}) =>
      CategoryConfiguration(
        id: id,
        slug: id,
        name: id,
        sectionId: section,
        sortOrder: order,
      );

  test(
    'registry returns only globally and customer enabled modules in order',
    () {
      final registry = BookMySpaceModuleRegistry.fromCategories([
        config('hotel', 2, section: 'lodge_rooms'),
        config('pg', 1, section: 'pg_hostels'),
        config('disabled', 0, section: 'function_halls'),
      ]);

      final modules = registry.enabled(
        globallyVisible: {'lodge_rooms', 'pg_hostels'},
        customerEnabled: {'pg_hostels', 'lodge_rooms'},
      );

      expect(modules.map((module) => module.id), ['pg', 'hotel']);
    },
  );

  test('a new configured category registers without Home code changes', () {
    final registry = BookMySpaceModuleRegistry.fromCategories([
      config('sports', 4),
    ]);

    expect(registry.resolve('sports')?.isGeneric, isTrue);
  });
}

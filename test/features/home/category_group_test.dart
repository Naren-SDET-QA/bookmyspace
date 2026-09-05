import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/home/domain/category_group.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';

CategoryConfiguration category(
  String id,
  String name,
  String sectionId, {
  int sortOrder = 0,
  bool homeVisible = true,
}) => CategoryConfiguration(
  id: id,
  slug: id,
  name: name,
  sectionId: sectionId,
  sortOrder: sortOrder,
  homeVisible: homeVisible,
);

void main() {
  test('groups database categories by section metadata', () {
    final groups = CategoryGroup.fromConfigurations([
      category('hotel', 'Hotel', 'lodge_rooms', sortOrder: 2),
      category('pg', 'PG', 'lodge_rooms', sortOrder: 1),
      category('class', 'Class', 'institutes_classes', sortOrder: 3),
      category('future', 'Future', ''),
    ]);

    expect(groups.map((group) => group.id), [
      'lodge_rooms',
      'institutes_classes',
    ]);
    expect(groups.first.name, 'Stay');
    expect(groups.first.categories.map((item) => item.id), ['pg', 'hotel']);
  });

  test('hidden or empty groups are fail-closed', () {
    final groups = CategoryGroup.fromConfigurations([
      category('hidden', 'Hidden', 'future', homeVisible: false),
    ]);

    expect(groups, isEmpty);
  });
}

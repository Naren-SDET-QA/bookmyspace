import '../../venues/domain/category_configuration.dart';

/// A database-derived parent used by the Home category index.
///
/// The group id comes from category metadata (`section_id`); adding a new
/// category only requires assigning that metadata, not a Dart enum change.
class CategoryGroup {
  const CategoryGroup({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.categories,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final List<CategoryConfiguration> categories;

  static List<CategoryGroup> fromConfigurations(
    Iterable<CategoryConfiguration> configurations,
  ) {
    final grouped = <String, List<CategoryConfiguration>>{};
    for (final config in configurations) {
      final id = config.sectionId.trim();
      if (id.isEmpty) continue;
      grouped.putIfAbsent(id, () => []).add(config);
    }
    return grouped.entries
        .map((entry) {
          final categories = [...entry.value]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final first = categories.first;
          final id = entry.key;
          return CategoryGroup(
            id: id,
            name: _displayName(id, first),
            slug: id,
            icon: _icon(id, first),
            sortOrder: categories
                .map((c) => c.sortOrder)
                .reduce((a, b) => a < b ? a : b),
            isActive: categories.any((c) => c.visible && c.homeVisible),
            categories: categories,
          );
        })
        .where((group) => group.isActive)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static String _displayName(String id, CategoryConfiguration first) {
    return switch (id.toLowerCase()) {
      'lodge_rooms' => 'Stay',
      'function_halls' => 'Spaces & Events',
      'institutes_classes' => 'Learning & Classes',
      'sports_activities' => 'Sports & Activities',
      _ => first.name,
    };
  }

  static String _icon(String id, CategoryConfiguration first) {
    return switch (id.toLowerCase()) {
      'lodge_rooms' => '🏨',
      'function_halls' => '🏛️',
      'institutes_classes' => '🎓',
      'sports_activities' => '⚽',
      _ => first.icon,
    };
  }
}

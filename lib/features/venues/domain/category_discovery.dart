import 'category_configuration.dart';

class CategoryDiscovery {
  const CategoryDiscovery._();

  static const int maxCarouselItems = 24;
  static const int maxQuery = 100;

  static List<CategoryConfiguration> homeVisible(
    List<CategoryConfiguration> items,
  ) {
    return items
        .where((item) => item.visible && item.homeVisible)
        .toList(growable: false);
  }

  static List<CategoryConfiguration> carouselItems(
    List<CategoryConfiguration> items,
  ) {
    final visible = List<CategoryConfiguration>.from(homeVisible(items))
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visible.length <= maxCarouselItems) return visible;
    return visible.take(maxCarouselItems).toList(growable: false);
  }

  static List<CategoryConfiguration> searchable(
    List<CategoryConfiguration> items,
  ) {
    return searchFilterCategories(items);
  }

  /// Categories offered by the search filter. This is intentionally based on
  /// database configuration so unknown categories do not need Dart changes.
  static List<CategoryConfiguration> searchFilterCategories(
    List<CategoryConfiguration> items, {
    String? sectionId,
  }) {
    final result = items
        .where((item) => item.visible && item.searchable)
        .where(
          (item) =>
              sectionId == null ||
              sectionId.isEmpty ||
              item.sectionId.isEmpty ||
              item.sectionId == sectionId,
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result.take(maxQuery).toList(growable: false);
  }

  static List<CategoryConfiguration> searchChips(
    List<CategoryConfiguration> items, {
    String? sectionId,
    List<CategoryConfiguration> fallback = const [],
  }) {
    return visibleChips(
      items,
      sectionId: sectionId,
      allow: (item) => item.searchable,
      fallback: fallback,
    );
  }

  static List<CategoryConfiguration> homeChips(
    List<CategoryConfiguration> items, {
    String? sectionId,
    List<CategoryConfiguration> fallback = const [],
  }) {
    return visibleChips(
      items,
      sectionId: sectionId,
      allow: (item) => item.homeVisible,
      fallback: fallback,
    );
  }

  static List<CategoryConfiguration> visibleChips(
    List<CategoryConfiguration> items, {
    String? sectionId,
    required bool Function(CategoryConfiguration item) allow,
    List<CategoryConfiguration> fallback = const [],
  }) {
    final visible = items.where((item) {
      if (!item.visible || !allow(item)) return false;
      if (sectionId == null || sectionId.isEmpty) return true;
      return item.sectionId.isEmpty || item.sectionId == sectionId;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (visible.isEmpty) return fallback;
    if (visible.length <= maxCarouselItems) return visible;
    return visible.take(maxCarouselItems).toList(growable: false);
  }

  static bool canBook(CategoryConfiguration? config) {
    if (config == null) return true;
    return config.visible && config.bookable && !config.isListingOnly;
  }
}

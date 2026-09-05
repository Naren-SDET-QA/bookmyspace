import '../../venues/domain/category_configuration.dart';
import 'customer_section_catalog.dart';

/// The Home catalog adapter. It keeps Home independent from category enums;
/// specialized legacy sections are represented by [sectionId], while unknown
/// database categories render through the generic venue section.
class HomeCategoryItem {
  const HomeCategoryItem(this.configuration);

  final CategoryConfiguration configuration;

  String get id => configuration.id;
  String get title => configuration.name;
  String get sectionId => configuration.sectionId;
  bool get isGeneric => sectionId.trim().isEmpty;
}

class HomeCategoryCatalog {
  const HomeCategoryCatalog._();

  /// Resolves the built-in first-screen sections from the admin-managed
  /// `app_customer_sections` rows. An empty list means the configuration has
  /// not loaded (or the database has no rows), so callers retain the seeded
  /// four-section fallback. A non-empty list is authoritative, including
  /// hiding every section when that is how an admin configured it.
  static List<CustomerSection> effectiveMainSections({
    required List<AppSectionConfig> configured,
    required Set<String> featureVisibleIds,
    required Set<String> customerEnabledIds,
  }) {
    final enabled = configured.isEmpty
        ? CustomerSection.values
        : configured
              .where((section) => section.visible)
              .map((section) => CustomerSection.fromId(section.id))
              .whereType<CustomerSection>();
    return enabled
        .where(
          (section) =>
              featureVisibleIds.contains(section.id) &&
              customerEnabledIds.contains(section.id),
        )
        .toList(growable: false);
  }

  static List<HomeCategoryItem> effective({
    required List<CategoryConfiguration> configurations,
    required Set<String> globallyVisible,
    required Set<String> customerEnabled,
  }) {
    final visible = configurations.where((configuration) {
      if (!configuration.visible || !configuration.homeVisible) return false;
      final globalId = configuration.sectionId.isNotEmpty
          ? configuration.sectionId
          : configuration.id;
      final globalAllowed =
          configuration.sectionId.isEmpty ||
          globallyVisible.contains(globalId) ||
          globallyVisible.contains(configuration.id);
      final customerAllowed =
          customerEnabled.contains(configuration.id) ||
          (configuration.sectionId.isNotEmpty &&
              customerEnabled.contains(configuration.sectionId));
      return globalAllowed && customerAllowed;
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // One home card represents a configured section. Multiple database
    // categories can therefore share a section without duplicating cards.
    final grouped = <String, CategoryConfiguration>{};
    for (final configuration in visible) {
      final key = configuration.sectionId.isNotEmpty
          ? configuration.sectionId
          : configuration.id;
      grouped.putIfAbsent(key, () => configuration);
    }
    return grouped.values.map(HomeCategoryItem.new).toList(growable: false);
  }
}

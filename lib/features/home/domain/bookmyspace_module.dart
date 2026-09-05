import '../../venues/domain/category_configuration.dart';

class BookMySpaceModule {
  const BookMySpaceModule(this.configuration);

  final CategoryConfiguration configuration;

  String get id => configuration.id;
  String get displayName => configuration.name;
  int get displayOrder => configuration.sortOrder;
  String get sectionId => configuration.sectionId;
  bool get isGeneric => sectionId.trim().isEmpty;

  bool isEnabled({
    required Set<String> globallyVisible,
    required Set<String> customerEnabled,
  }) {
    final scope = sectionId.isEmpty ? id : sectionId;
    return configuration.visible &&
        configuration.homeVisible &&
        (sectionId.isEmpty || globallyVisible.contains(scope)) &&
        (customerEnabled.contains(id) || customerEnabled.contains(scope));
  }
}

class BookMySpaceModuleRegistry {
  BookMySpaceModuleRegistry(Iterable<BookMySpaceModule> modules)
    : _modules = {for (final module in modules) module.id: module};

  factory BookMySpaceModuleRegistry.fromCategories(
    Iterable<CategoryConfiguration> configurations,
  ) => BookMySpaceModuleRegistry(configurations.map(BookMySpaceModule.new));

  final Map<String, BookMySpaceModule> _modules;

  BookMySpaceModule? resolve(String id) => _modules[id];

  List<BookMySpaceModule> enabled({
    required Set<String> globallyVisible,
    required Set<String> customerEnabled,
  }) {
    final enabled =
        _modules.values
            .where(
              (module) => module.isEnabled(
                globallyVisible: globallyVisible,
                customerEnabled: customerEnabled,
              ),
            )
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return enabled;
  }
}

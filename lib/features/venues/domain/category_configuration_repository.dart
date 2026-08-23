import 'category_configuration.dart';

abstract interface class CategoryConfigurationRepository {
  Future<List<CategoryConfiguration>> listActive();

  Future<List<AppSectionConfig>> sections();

  Future<CategoryConfiguration> updateMetadata({
    required String categoryId,
    required Map<String, dynamic> metadata,
  });

  Future<AppSectionConfig> updateSectionVisibility({
    required String sectionId,
    required bool visible,
  });
}

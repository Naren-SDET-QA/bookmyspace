import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/category_configuration.dart';
import '../domain/category_configuration_repository.dart';
import '../domain/venue.dart';

class SupabaseCategoryConfigurationRepository
    implements CategoryConfigurationRepository {
  SupabaseCategoryConfigurationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CategoryConfiguration>> listActive() async {
    try {
      final rows = await _client
          .from('venue_categories')
          .select('id, slug, name, icon, metadata')
          .order('name')
          .limit(100);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(VenueCategory.fromJson)
          .map(CategoryConfiguration.fromCategory)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<AppSectionConfig>> sections() async {
    try {
      final rows = await _client
          .from('app_customer_sections')
          .select()
          .order('sort_order');
      return rows
          .whereType<Map<String, dynamic>>()
          .map(AppSectionConfig.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<CategoryConfiguration> updateMetadata({
    required String categoryId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'admin_update_category_metadata',
        params: {'p_category_id': categoryId, 'p_metadata': metadata},
      );
      return CategoryConfiguration.fromCategory(VenueCategory.fromJson(row));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<AppSectionConfig> updateSectionVisibility({
    required String sectionId,
    required bool visible,
  }) async {
    try {
      final rows = await _client
          .from('app_customer_sections')
          .update({'is_visible': visible})
          .eq('id', sectionId)
          .select();
      final row = rows.whereType<Map<String, dynamic>>().firstOrNull;
      if (row == null) {
        throw StateError('Section not found');
      }
      return AppSectionConfig.fromJson(row);
    } catch (e) {
      throw mapError(e);
    }
  }
}

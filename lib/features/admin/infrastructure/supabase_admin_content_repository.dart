import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/admin_content_repository.dart';
import '../domain/content_models.dart';

class SupabaseAdminContentRepository implements AdminContentRepository {
  SupabaseAdminContentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<HomepageContentConfig> homepageConfig() async {
    try {
      final raw = await _client.rpc<dynamic>('get_homepage_content_config');
      if (raw is Map<String, dynamic>) {
        return HomepageContentConfig.fromJson(raw);
      }
      if (raw is Map) {
        return HomepageContentConfig.fromJson(Map<String, dynamic>.from(raw));
      }
      return const HomepageContentConfig();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<HomepageSection>> listHomepageSections({
    bool includeHidden = true,
  }) async {
    try {
      var q = _client.from('homepage_sections').select('*');
      if (!includeHidden) {
        q = q.eq('is_visible', true);
      }
      final rows = await q.order('sort_order');
      return rows.map(HomepageSection.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<HomeCategoryTile>> listCategoryTiles({
    bool includeHidden = true,
  }) async {
    try {
      var q = _client.from('home_category_tiles').select('*');
      if (!includeHidden) {
        q = q.eq('is_visible', true);
      }
      final rows = await q.order('sort_order');
      return rows.map(HomeCategoryTile.fromJson).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<AdminContentVenue>> listVenues({
    String? query,
    int limit = 50,
  }) async {
    try {
      final rows = await _client.rpc<dynamic>(
        'admin_list_content_venues',
        params: {'p_query': query, 'p_limit': limit},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(AdminContentVenue.fromJson)
          .toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<AdminContentVenue> updateVenueContent(
    String venueId,
    Map<String, dynamic> patch,
  ) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_update_venue_content',
        params: {'p_venue_id': venueId, 'p_patch': patch},
      );
      return AdminContentVenue.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<AdminContentVenue> approveVenue(
    String venueId, {
    required bool approve,
    String? notes,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_approve_venue',
        params: {
          'p_venue_id': venueId,
          'p_approve': approve,
          'p_notes': notes,
        },
      );
      return AdminContentVenue.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<int> replaceVenueImages(
    String venueId,
    List<Map<String, dynamic>> images,
  ) async {
    try {
      final count = await _client.rpc<dynamic>(
        'admin_replace_venue_images',
        params: {'p_venue_id': venueId, 'p_images': images},
      );
      return (count as num?)?.toInt() ?? 0;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<int> setVenueAmenities(String venueId, List<String> amenities) async {
    try {
      final count = await _client.rpc<dynamic>(
        'admin_set_venue_amenities',
        params: {'p_venue_id': venueId, 'p_amenities': amenities},
      );
      return (count as num?)?.toInt() ?? 0;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<HomepageSection> upsertHomepageSection({
    required String sectionKey,
    required String title,
    String? emoji,
    int? sortOrder,
    bool? isVisible,
    Map<String, dynamic>? config,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_upsert_homepage_section',
        params: {
          'p_section_key': sectionKey,
          'p_title': title,
          'p_emoji': emoji,
          'p_sort_order': sortOrder,
          'p_is_visible': isVisible,
          'p_config': config,
        },
      );
      return HomepageSection.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<int> reorderHomepageSections(List<String> orderedKeys) async {
    try {
      final count = await _client.rpc<dynamic>(
        'admin_reorder_homepage_sections',
        params: {'p_ordered_keys': orderedKeys},
      );
      return (count as num?)?.toInt() ?? 0;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<HomeCategoryTile> upsertCategoryTile({
    required String tileKey,
    required String label,
    required String emoji,
    required String routeTarget,
    int? sortOrder,
    bool? isVisible,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_upsert_home_category_tile',
        params: {
          'p_tile_key': tileKey,
          'p_label': label,
          'p_emoji': emoji,
          'p_route_target': routeTarget,
          'p_sort_order': sortOrder,
          'p_is_visible': isVisible,
        },
      );
      return HomeCategoryTile.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateCategoryDisplay({
    required String categoryId,
    String? displayName,
    String? icon,
    int? sortOrder,
    bool? isHomeVisible,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_update_category_display',
        params: {
          'p_category_id': categoryId,
          'p_display_name': displayName,
          'p_icon': icon,
          'p_sort_order': sortOrder,
          'p_is_home_visible': isHomeVisible,
        },
      );
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> setPlatformSetting({
    required String key,
    required Map<String, dynamic> value,
    String? description,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_set_platform_setting',
        params: {
          'p_key': key,
          'p_value': value,
          'p_description': description,
        },
      );
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> setOrgCommission({
    required String orgId,
    required double commissionRate,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'admin_set_org_commission',
        params: {
          'p_org_id': orgId,
          'p_commission_rate': commissionRate,
        },
      );
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

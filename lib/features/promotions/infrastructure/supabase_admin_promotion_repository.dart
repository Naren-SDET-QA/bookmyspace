import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/promotion.dart';

class SupabaseAdminPromotionRepository {
  SupabaseAdminPromotionRepository(this._client);
  final SupabaseClient _client;

  Future<void> saveGlobalFlag(String key, bool value) async {
    try {
      final existing = await _client
          .from('module_feature_configs')
          .select('id, metadata')
          .eq('module_key', 'promotions')
          .isFilter('venue_id', null)
          .maybeSingle();
      final metadata = Map<String, dynamic>.from(
        (existing?['metadata'] as Map?) ?? const <String, dynamic>{},
      )..[key] = value;
      if (existing == null) {
        await _client.from('module_feature_configs').insert({
          'module_key': 'promotions',
          'metadata': metadata,
        });
      } else {
        await _client
            .from('module_feature_configs')
            .update({'metadata': metadata})
            .eq('id', existing['id'] as Object);
      }
    } catch (error) {
      throw mapError(error);
    }
  }

  static const _select =
      '*, promotion_categories(category_id), promotion_venues(venue_id)';

  Future<List<Promotion>> listAll() async {
    try {
      final rows = await _client
          .from('promotions')
          .select(_select)
          .order('priority', ascending: false)
          .order('sort_order');
      return rows.map(Promotion.fromJson).toList(growable: false);
    } catch (error) {
      throw mapError(error);
    }
  }

  Future<Promotion> save(Promotion promotion) async {
    try {
      final row = await _client
          .from('promotions')
          .upsert({
            if (promotion.id.isNotEmpty) 'id': promotion.id,
            'title': promotion.title,
            'short_description': promotion.shortDescription,
            'description': promotion.description,
            'banner_media_id': promotion.bannerMediaId,
            'active': promotion.active,
            'start_at': promotion.startAt?.toUtc().toIso8601String(),
            'end_at': promotion.endAt?.toUtc().toIso8601String(),
            'priority': promotion.priority,
            'sort_order': promotion.sortOrder,
            'cta_text': promotion.ctaText,
            'cta_action': promotion.ctaAction,
            'offer_type': promotion.offerType,
            'discount_type': promotion.discountType,
            'discount_value': promotion.discountValue,
            'accent_color': promotion.accentColor,
            'background_color': promotion.backgroundColor,
            'text_color': promotion.textColor,
            'badge': promotion.badge,
            'icon': promotion.icon,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select(_select)
          .single();
      final saved = Promotion.fromJson(row);
      await _replaceTargets(
        saved.id,
        promotion.categoryIds,
        promotion.venueIds,
      );
      return saved;
    } catch (error) {
      throw mapError(error);
    }
  }

  Future<void> _replaceTargets(
    String promotionId,
    List<String> categoryIds,
    List<String> venueIds,
  ) async {
    await _client
        .from('promotion_categories')
        .delete()
        .eq('promotion_id', promotionId);
    await _client
        .from('promotion_venues')
        .delete()
        .eq('promotion_id', promotionId);
    if (categoryIds.isNotEmpty) {
      await _client.from('promotion_categories').insert([
        for (final id in categoryIds)
          {'promotion_id': promotionId, 'category_id': id},
      ]);
    }
    if (venueIds.isNotEmpty) {
      await _client.from('promotion_venues').insert([
        for (final id in venueIds)
          {'promotion_id': promotionId, 'venue_id': id},
      ]);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('promotions').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }

  Future<void> updateOrder({required String id, required int sortOrder}) async {
    try {
      await _client
          .from('promotions')
          .update({'sort_order': sortOrder})
          .eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }
}

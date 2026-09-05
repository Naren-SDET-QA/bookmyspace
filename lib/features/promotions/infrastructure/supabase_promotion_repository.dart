import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/promotion.dart';
import '../domain/promotion_repository.dart';

class SupabasePromotionRepository implements PromotionRepository {
  SupabasePromotionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Promotion>> listActive({int limit = 10}) async {
    try {
      final rows = await _client
          .from('promotions')
          .select(
            '*, promotion_categories(category_id), promotion_venues(venue_id)',
          )
          .eq('active', true)
          .order('priority', ascending: false)
          .order('sort_order')
          .limit(limit.clamp(1, 10));
      return rows.map(Promotion.fromJson).toList(growable: false);
    } catch (error) {
      throw mapError(error);
    }
  }
}

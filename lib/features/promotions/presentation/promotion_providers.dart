import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../../core/modular/feature_providers.dart';
import '../domain/promotion.dart';
import '../domain/promotion_capabilities.dart';
import '../infrastructure/supabase_promotion_repository.dart';

final promotionRepositoryProvider = Provider<SupabasePromotionRepository>((
  ref,
) {
  return SupabasePromotionRepository(ref.watch(supabaseProvider));
});

final activePromotionsProvider = FutureProvider<List<Promotion>>((ref) {
  if (!PromotionCapabilities(
    ref.watch(featureRegistryProvider),
  ).promotionsEnabled) {
    return const [];
  }
  return ref.watch(promotionRepositoryProvider).listActive(limit: 10);
});

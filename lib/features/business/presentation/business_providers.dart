import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/pricing_feature.dart';
import '../domain/business_plan.dart';
import '../infrastructure/supabase_business_config_repository.dart';

final businessConfigRepositoryProvider =
    Provider<SupabaseBusinessConfigRepository>(
      (ref) => SupabaseBusinessConfigRepository(ref.watch(supabaseProvider)),
    );

final activePricingFeaturesProvider = FutureProvider<List<PricingFeature>>(
  (ref) => ref.watch(businessConfigRepositoryProvider).activePricing(),
);

final activeBusinessPlansProvider = FutureProvider<List<BusinessPlan>>(
  (ref) => ref.watch(businessConfigRepositoryProvider).activePlans(),
);

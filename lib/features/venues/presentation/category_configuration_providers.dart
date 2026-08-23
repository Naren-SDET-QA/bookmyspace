import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/category_configuration.dart';
import '../domain/category_configuration_repository.dart';
import '../infrastructure/supabase_category_configuration_repository.dart';

final categoryConfigurationRepositoryProvider =
    Provider<CategoryConfigurationRepository>((ref) {
      return SupabaseCategoryConfigurationRepository(
        ref.watch(supabaseProvider),
      );
    });

final categoryConfigurationsProvider =
    FutureProvider<List<CategoryConfiguration>>((ref) async {
      try {
        return await ref
            .watch(categoryConfigurationRepositoryProvider)
            .listActive();
      } catch (_) {
        return const [];
      }
    });

final appCustomerSectionsProvider = FutureProvider<List<AppSectionConfig>>((
  ref,
) async {
  try {
    return await ref.watch(categoryConfigurationRepositoryProvider).sections();
  } catch (_) {
    return const [];
  }
});

final categoryAliasIndexProvider = Provider<CategoryAliasIndex>((ref) {
  final configs =
      ref.watch(categoryConfigurationsProvider).valueOrNull ?? const [];
  return CategoryAliasIndex(configs);
});

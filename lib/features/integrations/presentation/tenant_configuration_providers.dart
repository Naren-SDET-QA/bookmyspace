import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/tenant_configuration_repository.dart';
import '../infrastructure/supabase_tenant_configuration_repository.dart';
import '../domain/tenant_configuration.dart';

final tenantConfigurationRepositoryProvider =
    Provider<TenantConfigurationRepository>((ref) {
  return SupabaseTenantConfigurationRepository(ref.watch(supabaseProvider));
});

/// Shared, lazily loaded tenant configuration. Screens should depend on this
/// provider instead of fetching organization configuration independently.
final tenantRuntimeConfigurationProvider =
    FutureProvider.family<TenantConfiguration, String>((ref, organizationId) {
  return ref.watch(tenantConfigurationRepositoryProvider).load(organizationId);
});

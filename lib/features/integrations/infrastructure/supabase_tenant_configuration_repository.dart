import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tenant_configuration.dart';
import '../domain/tenant_configuration_repository.dart';

class SupabaseTenantConfigurationRepository
    implements TenantConfigurationRepository {
  SupabaseTenantConfigurationRepository(this.client);
  final SupabaseClient client;

  @override
  Future<TenantConfiguration> load(String organizationId) async {
    final row = await client
        .from('organization_configurations')
        .select()
        .eq('organization_id', organizationId)
        .maybeSingle();
    final categories = await client
        .from('organization_category_configurations')
        .select('category_id, configuration')
        .eq('organization_id', organizationId);
    final overrides = <String, Map<String, dynamic>>{};
    for (final row in (categories as List)) {
      final id = row['category_id']?.toString();
      final value = row['configuration'];
      if (id != null && value is Map) {
        overrides[id] = value.cast<String, dynamic>();
      }
    }
    return TenantConfiguration.fromJson({
      ...?row,
      'organization_id': organizationId,
      'category_overrides': overrides,
    });
  }

  @override
  Future<TenantConfiguration> save(TenantConfiguration configuration) async {
    final row = {
      'organization_id': configuration.organizationId,
      'branding': configuration.branding,
      'theme': configuration.theme,
      'language': configuration.language,
      'features': configuration.features,
      'booking': configuration.booking,
      'notifications': configuration.notifications,
      'media': configuration.media,
      'voice': configuration.voice,
      'categories': configuration.categories,
      'configuration_version': configuration.version,
    };
    await client.from('organization_configurations').upsert(row);
    for (final entry in configuration.categoryOverrides.entries) {
      await client.from('organization_category_configurations').upsert({
        'organization_id': configuration.organizationId,
        'category_id': entry.key,
        'configuration': entry.value,
      });
    }
    return configuration;
  }
}

import 'tenant_configuration.dart';

abstract interface class TenantConfigurationRepository {
  Future<TenantConfiguration> load(String organizationId);
  Future<TenantConfiguration> save(TenantConfiguration configuration);
}

import '../domain/tenant_configuration.dart';
import '../domain/tenant_configuration_repository.dart';

class TenantConfigurationController {
  TenantConfigurationController(this.repository, this.organizationId);
  final TenantConfigurationRepository repository;
  final String organizationId;
  TenantConfiguration configuration = const TenantConfiguration(organizationId: '');
  bool _loaded = false;

  Future<TenantConfiguration> load() async {
    if (_loaded) return configuration;
    try {
      configuration = await repository.load(organizationId);
    } catch (_) {
      configuration = TenantConfiguration(organizationId: organizationId);
    }
    _loaded = true;
    return configuration;
  }

  Future<TenantConfiguration> refresh() async {
    _loaded = false;
    return load();
  }

  Future<void> setFeature(String key, bool enabled) async {
    await load();
    final features = {...configuration.features, key: enabled};
    configuration = configuration.copyWith(features: features);
    await repository.save(configuration);
  }
}

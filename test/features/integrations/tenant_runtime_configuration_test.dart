import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/integrations/domain/tenant_configuration.dart';
import 'package:bookmyspace/features/integrations/domain/tenant_configuration_repository.dart';
import 'package:bookmyspace/features/integrations/presentation/tenant_configuration_controller.dart';

class _MemoryTenantRepository implements TenantConfigurationRepository {
  TenantConfiguration value;
  _MemoryTenantRepository(this.value);
  int reads = 0;
  @override
  Future<TenantConfiguration> load(String organizationId) async { reads++; return value; }
  @override
  Future<TenantConfiguration> save(TenantConfiguration configuration) async { value = configuration; return value; }
}

void main() {
  test('resolves category overrides over tenant defaults', () {
    const config = TenantConfiguration(
      organizationId: 'org',
      features: {'booking': true, 'maps': false},
      categoryOverrides: {'hotel': {'booking': false}},
    );
    expect(config.isEnabled('booking'), isTrue);
    expect(config.isEnabled('maps'), isFalse);
    expect(config.isEnabled('booking', categorySlug: 'hotel'), isFalse);
  });

  test('missing configuration fails safe to defaults', () {
    const config = TenantConfiguration(organizationId: 'org');
    expect(config.isEnabled('unknown'), isFalse);
    expect(config.stringValue('missing', fallback: 'default'), 'default');
  });

  test('runtime loader caches and refreshes configuration', () async {
    final repository = _MemoryTenantRepository(
      const TenantConfiguration(organizationId: 'org', features: {'booking': true}),
    );
    final controller = TenantConfigurationController(repository, 'org');
    await controller.load();
    await controller.load();
    expect(repository.reads, 1);
    repository.value = const TenantConfiguration(organizationId: 'org', features: {'booking': false});
    await controller.refresh();
    expect(controller.configuration.isEnabled('booking'), isFalse);
    expect(repository.reads, 2);
  });

  test('updates a feature without losing unrelated configuration', () async {
    final repository = _MemoryTenantRepository(
      const TenantConfiguration(organizationId: 'org', branding: {'name': 'Space'}, features: {'maps': true}),
    );
    final controller = TenantConfigurationController(repository, 'org');
    await controller.load();
    await controller.setFeature('maps', false);
    expect(controller.configuration.branding['name'], 'Space');
    expect(controller.configuration.isEnabled('maps'), isFalse);
  });
}

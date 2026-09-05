import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/integrations/domain/tenant_configuration.dart';

void main() {
  test('observability settings resolve global then category then feature overrides', () {
    const config = TenantConfiguration(
      organizationId: 'org-1',
      features: {'observability': true, 'observability.alerts': false},
      categoryOverrides: {
        'halls': {'observability.alerts': true, 'observability.metrics': false},
      },
    );
    expect(config.observabilitySetting('observability'), isTrue);
    expect(config.observabilitySetting('alerts'), isFalse);
    expect(config.observabilitySetting('alerts', categorySlug: 'halls'), isTrue);
    expect(config.observabilitySetting('metrics', categorySlug: 'halls'), isFalse);
    expect(config.observabilitySetting('recovery', fallback: false), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/integrations/domain/tenant_configuration.dart';

void main() {
  test('tenant configuration resolves global values before category overrides', () {
    const config = TenantConfiguration(
      organizationId: 'org-1',
      features: {'booking': true, 'voice': false},
      categoryOverrides: {
        'hotel': {'voice': true, 'booking': false},
      },
    );

    expect(config.resolve('booking'), isTrue);
    expect(config.resolve('voice', categorySlug: 'hotel'), isTrue);
    expect(config.resolve('booking', categorySlug: 'hotel'), isFalse);
    expect(config.resolve('qr'), isNull);
  });

  test('configuration never treats credential-shaped values as client config', () {
    final config = TenantConfiguration.fromJson({
      'organization_id': 'org-1',
      'features': {'email': true, 'api_key': 'should-not-be-used'},
    });
    expect(config.features.containsKey('api_key'), isFalse);
  });
}

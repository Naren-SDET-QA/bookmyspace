import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/integrations/domain/integration_config.dart';

void main() {
  test('parses generic integration configuration without secrets', () {
    final config = IntegrationConfig.fromJson({
      'id': 'integration-1',
      'name': 'Calendar',
      'slug': 'calendar',
      'type': 'REST_API',
      'provider': 'example',
      'enabled': true,
      'configuration': {'timeout_ms': 5000},
      'input_schema': {'type': 'object'},
      'output_schema': {'type': 'object'},
    });

    expect(config.type, 'REST_API');
    expect(config.enabled, isTrue);
    expect(config.configuration['timeout_ms'], 5000);
    expect(config.toSafeJson(), isNot(contains('secret')));
  });

  test('unknown integration types remain data-driven', () {
    final config = IntegrationConfig.fromJson({
      'name': 'Future connector',
      'slug': 'future-connector',
      'type': 'FUTURE_PROTOCOL',
    });

    expect(config.type, 'FUTURE_PROTOCOL');
    expect(config.enabled, isFalse);
  });
}

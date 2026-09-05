import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/admin/domain/observability_control_plane.dart';

void main() {
  test('effective setting reports the highest-priority override and source', () {
    final result = EffectiveObservabilitySetting.resolve(
      key: 'alerts',
      global: true,
      tenant: false,
      category: true,
      feature: null,
    );
    expect(result.value, isTrue);
    expect(result.source, ObservabilitySettingSource.category);
  });

  test('effective setting falls back to global when overrides are absent', () {
    final result = EffectiveObservabilitySetting.resolve(
      key: 'metrics', global: false,
    );
    expect(result.value, isFalse);
    expect(result.source, ObservabilitySettingSource.global);
  });

  test('provider health maps missing timestamps to safe unknown state', () {
    final health = ProviderHealth.fromMap({'status': 'healthy'});
    expect(health.status, 'healthy');
    expect(health.lastSuccess, isNull);
    expect(health.lastFailure, isNull);
    expect(health.circuitState, 'UNKNOWN');
  });
}

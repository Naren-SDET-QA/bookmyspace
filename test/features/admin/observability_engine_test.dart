import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/admin/domain/observability_engine.dart';

void main() {
  test('alert evaluator respects enabled state and threshold window', () {
    final evaluator = AlertEvaluator();
    expect(evaluator.isTriggered(AlertRule(metric: 'error_rate', threshold: 3, window: 60, enabled: false), 10), isFalse);
    expect(evaluator.isTriggered(AlertRule(metric: 'error_rate', threshold: 3, window: 60, enabled: true), 2), isFalse);
    expect(evaluator.isTriggered(AlertRule(metric: 'error_rate', threshold: 3, window: 60, enabled: true), 3), isTrue);
  });

  test('recovery retries are bounded and circuit opens after failures', () {
    final recovery = RecoveryController(maxRetries: 2);
    expect(recovery.nextAction(), RecoveryAction.retry);
    expect(recovery.nextAction(), RecoveryAction.retry);
    expect(recovery.nextAction(), RecoveryAction.degraded);
    expect(recovery.nextAction(), RecoveryAction.degraded);
    recovery.recordProbeSuccess();
    expect(recovery.nextAction(), RecoveryAction.recovered);
  });

  test('metrics calculate bounded error rate', () {
    final metrics = MetricsSnapshot(requests: 10, errors: 2, latencyMs: 120, recoveries: 1, alerts: 2);
    expect(metrics.errorRate, 0.2);
    expect(metrics.bounded(limit: 3).requests, 3);
  });

  test('redactor removes credential-shaped values and auth headers', () {
    final safe = SensitiveDataRedactor.redact({'Authorization': 'Bearer secret', 'token': 'abc', 'message': 'failed'});
    expect(safe['Authorization'], '[REDACTED]');
    expect(safe['token'], '[REDACTED]');
    expect(safe['message'], 'failed');
  });
}

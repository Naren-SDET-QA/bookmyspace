class AlertRule {
  final String metric;
  final double threshold;
  final int window;
  final bool enabled;

  const AlertRule({required this.metric, required this.threshold, required this.window, required this.enabled});
}

class AlertEvaluator {
  bool isTriggered(AlertRule rule, num value) => rule.enabled && value >= rule.threshold && rule.window > 0;
}

enum RecoveryAction { retry, degraded, recovered }

class RecoveryController {
  final int maxRetries;
  int _attempts = 0;
  bool _degraded = false;
  bool _recovered = false;

  RecoveryController({this.maxRetries = 3}) : assert(maxRetries >= 0);

  RecoveryAction nextAction() {
    if (_recovered) return RecoveryAction.recovered;
    if (_degraded) return RecoveryAction.degraded;
    if (_attempts < maxRetries) {
      _attempts++;
      return RecoveryAction.retry;
    }
    _degraded = true;
    return RecoveryAction.degraded;
  }

  void recordProbeSuccess() {
    if (_degraded) _recovered = true;
  }
}

class MetricsSnapshot {
  final int requests;
  final int errors;
  final int latencyMs;
  final int recoveries;
  final int alerts;

  const MetricsSnapshot({required this.requests, required this.errors, required this.latencyMs, required this.recoveries, required this.alerts});

  double get errorRate => requests == 0 ? 0 : errors / requests;

  MetricsSnapshot bounded({int limit = 1000}) => MetricsSnapshot(
        requests: requests.clamp(0, limit),
        errors: errors.clamp(0, limit),
        latencyMs: latencyMs.clamp(0, limit * 1000),
        recoveries: recoveries.clamp(0, limit),
        alerts: alerts.clamp(0, limit),
      );
}

class SensitiveDataRedactor {
  static const _sensitive = {'authorization', 'apikey', 'api_key', 'password', 'secret', 'token', 'credential'};

  static Map<String, dynamic> redact(Map<String, dynamic> input) => {
        for (final entry in input.entries)
          entry.key: _sensitive.any((key) => entry.key.toLowerCase().contains(key)) ? '[REDACTED]' : entry.value,
      };
}

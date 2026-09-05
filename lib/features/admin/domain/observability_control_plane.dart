enum ObservabilitySettingSource { feature, category, tenant, global, defaultValue }

class EffectiveObservabilitySetting {
  const EffectiveObservabilitySetting(this.key, this.value, this.source);

  final String key;
  final bool value;
  final ObservabilitySettingSource source;

  static EffectiveObservabilitySetting resolve({
    required String key,
    bool? global,
    bool? tenant,
    bool? category,
    bool? feature,
    bool fallback = false,
  }) {
    if (feature != null) return EffectiveObservabilitySetting(key, feature, ObservabilitySettingSource.feature);
    if (category != null) return EffectiveObservabilitySetting(key, category, ObservabilitySettingSource.category);
    if (tenant != null) return EffectiveObservabilitySetting(key, tenant, ObservabilitySettingSource.tenant);
    if (global != null) return EffectiveObservabilitySetting(key, global, ObservabilitySettingSource.global);
    return EffectiveObservabilitySetting(key, fallback, ObservabilitySettingSource.defaultValue);
  }

  String get sourceLabel => switch (source) {
        ObservabilitySettingSource.feature => 'Feature override',
        ObservabilitySettingSource.category => 'Category override',
        ObservabilitySettingSource.tenant => 'Tenant override',
        ObservabilitySettingSource.global => 'Global',
        ObservabilitySettingSource.defaultValue => 'Default',
      };
}

class ProviderHealth {
  const ProviderHealth({
    required this.status,
    this.lastSuccess,
    this.lastFailure,
    this.circuitState = 'UNKNOWN',
  });

  final String status;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final String circuitState;

  factory ProviderHealth.fromMap(Map<String, dynamic> map) => ProviderHealth(
        status: map['status']?.toString() ?? 'unknown',
        lastSuccess: _date(map['last_success_at']),
        lastFailure: _date(map['last_failure_at']),
        circuitState: map['circuit_state']?.toString() ?? 'UNKNOWN',
      );

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse(value.toString());
}

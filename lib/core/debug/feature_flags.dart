import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single toggleable feature flag.
class FeatureFlag {
  const FeatureFlag(this.key, this.label, {this.defaultValue = true});

  final String key;
  final String label;
  final bool defaultValue;
}

/// Application feature flags. Defaults are tuned for a production-like
/// testing environment; the debug menu can toggle them at runtime.
const List<FeatureFlag> appFeatureFlags = [
  FeatureFlag('functionHall', 'Function Hall category'),
  FeatureFlag('hotels', 'Hotel / Stay category'),
  FeatureFlag('pg', 'PG / Co-Living category'),
  FeatureFlag('events', 'Events'),
  FeatureFlag('courses', 'Courses'),
  FeatureFlag('reviews', 'Reviews'),
  FeatureFlag('notifications', 'In-app notifications'),
  FeatureFlag('wallet', 'Wallet payments'),
  FeatureFlag('mapSearch', 'Map search'),
];

class FeatureFlagsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    return {
      for (final f in appFeatureFlags) f.key: f.defaultValue,
    };
  }

  bool isEnabled(String key) => state[key] ?? true;

  void setEnabled(String key, bool value) {
    state = {...state, key: value};
  }

  void reset() => state = {
        for (final f in appFeatureFlags) f.key: f.defaultValue,
      };
}

final featureFlagsProvider = NotifierProvider<FeatureFlagsNotifier, Map<String, bool>>(
  FeatureFlagsNotifier.new,
);

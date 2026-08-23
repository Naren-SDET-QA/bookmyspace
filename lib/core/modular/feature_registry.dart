import 'package:flutter/foundation.dart';

import 'feature_config.dart';
import 'feature_id.dart';

/// Single place to enable, disable, and reconfigure product capabilities.
class FeatureRegistry {
  FeatureRegistry(Map<FeatureId, FeatureConfig> configs)
    : _configs = Map<FeatureId, FeatureConfig>.from(configs);

  final Map<FeatureId, FeatureConfig> _configs;

  static FeatureRegistry instance = FeatureRegistry.defaults();

  /// Lets Riverpod rebuild when [configure]/[apply] mutate the singleton.
  static VoidCallback? onChanged;

  factory FeatureRegistry.defaults() {
    return FeatureRegistry({
      for (final id in FeatureId.values) id: FeatureConfig.defaultFor(id),
    });
  }

  static void reset() {
    onChanged = null;
    instance = FeatureRegistry.defaults();
  }

  static void configure(
    FeatureId id, {
    bool? enabled,
    String? provider,
    Map<String, Object?>? config,
  }) {
    instance.apply(id, enabled: enabled, provider: provider, config: config);
  }

  FeatureConfig configOf(FeatureId id) =>
      _configs[id] ?? FeatureConfig.defaultFor(id);

  bool isEnabled(FeatureId id) => configOf(id).enabled;

  FeatureAvailability availability(FeatureId id) {
    final config = configOf(id);
    if (!config.enabled) {
      return FeatureAvailability(
        enabled: false,
        available: false,
        reason: '${id.name} is disabled',
      );
    }
    final missing = config.dependencies
        .where((dep) => !isEnabled(dep))
        .toList(growable: false);
    if (missing.isEmpty) {
      return const FeatureAvailability(enabled: true, available: true);
    }
    return FeatureAvailability(
      enabled: true,
      available: false,
      missingDependencies: missing,
      reason: '${id.name} needs ${missing.map((item) => item.name).join(', ')}',
    );
  }

  bool isExposed(FeatureId id) => availability(id).available;

  void apply(
    FeatureId id, {
    bool? enabled,
    String? provider,
    Map<String, Object?>? config,
  }) {
    _configs[id] = configOf(
      id,
    ).copyWith(enabled: enabled, provider: provider, config: config);
    onChanged?.call();
  }

  /// Home catalog ids that should be shown. Unknown DB categories are not
  /// represented here; they continue to work via [CategoryConfiguration].
  List<String> visibleHomeSections() {
    return [
      if (_homeVisible(FeatureId.functionHall)) 'function_halls',
      if (_homeVisible(FeatureId.hotels)) 'lodge_rooms',
      if (_homeVisible(FeatureId.pg)) 'pg_hostels',
      if (_homeVisible(FeatureId.institutes)) 'institutes_classes',
    ];
  }

  bool _homeVisible(FeatureId id) =>
      isExposed(id) && (configOf(id).config['home_visible'] as bool? ?? true);

  /// Search catalog ids that should be shown. Unknown DB categories continue
  /// via [CategoryConfiguration.searchable].
  List<String> visibleSearchSections() {
    return [
      if (_searchVisible(FeatureId.functionHall)) 'function_halls',
      if (_searchVisible(FeatureId.hotels)) 'lodge_rooms',
      if (_searchVisible(FeatureId.pg)) 'pg_hostels',
      if (_searchVisible(FeatureId.institutes)) 'institutes_classes',
    ];
  }

  bool _searchVisible(FeatureId id) =>
      isExposed(id) && (configOf(id).config['search_visible'] as bool? ?? true);

  bool isBookingEnabled(FeatureId id) {
    if (id != FeatureId.booking && !isExposed(FeatureId.booking)) return false;
    if (!isExposed(id)) return false;
    final configured = configOf(id).config['booking_enabled'];
    if (configured is bool) return configured;
    return switch (id) {
      FeatureId.institutes => false,
      FeatureId.functionHall ||
      FeatureId.hotels ||
      FeatureId.pg ||
      FeatureId.courses ||
      FeatureId.events ||
      FeatureId.booking => true,
      _ => false,
    };
  }

  bool isOfferVisible(FeatureId id) {
    if (!isExposed(FeatureId.offers)) return false;
    return configOf(id).config['offer_visible'] as bool? ?? true;
  }

  bool isQrVisible() =>
      isExposed(FeatureId.barcode) &&
      (configOf(FeatureId.barcode).config['qr_visible'] as bool? ?? true);

  static FeatureId? featureForRoute(String location) {
    if (location == '/map' || location.startsWith('/map'))
      return FeatureId.maps;
    if (location == '/search' || location.startsWith('/search')) {
      return FeatureId.search;
    }
    if (location == '/events' || location.startsWith('/events')) {
      return FeatureId.events;
    }
    if (location == '/courses' || location.startsWith('/courses')) {
      return FeatureId.courses;
    }
    if (location == '/institutes' || location.startsWith('/institutes')) {
      return FeatureId.institutes;
    }
    if (location == '/assistant') return FeatureId.ai;
    if (location == '/notifications') return FeatureId.notifications;
    if (location == '/payments' || location.endsWith('/pay')) {
      return FeatureId.payments;
    }
    if (location == '/bookings' ||
        location.startsWith('/bookings') ||
        location.endsWith('/book')) {
      return FeatureId.booking;
    }
    if (location == '/register' || location.startsWith('/register')) {
      return FeatureId.registration;
    }
    if (location == '/analytics' || location == '/my-analytics') {
      return FeatureId.analytics;
    }
    if (location == '/check-in' || location.startsWith('/check-in')) {
      return FeatureId.barcode;
    }
    return null;
  }
}

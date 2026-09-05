import 'feature_id.dart';

/// Central per-feature knobs. Screens must not copy this map.
class FeatureConfig {
  const FeatureConfig({
    this.enabled = true,
    this.provider,
    this.config = const {},
    this.dependencies = const [],
    this.optionalDependencies = const [],
  });

  final bool enabled;
  final String? provider;
  final Map<String, Object?> config;
  final List<FeatureId> dependencies;
  final List<FeatureId> optionalDependencies;

  FeatureConfig copyWith({
    bool? enabled,
    String? provider,
    Map<String, Object?>? config,
    List<FeatureId>? dependencies,
    List<FeatureId>? optionalDependencies,
  }) {
    return FeatureConfig(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      config: config ?? this.config,
      dependencies: dependencies ?? this.dependencies,
      optionalDependencies: optionalDependencies ?? this.optionalDependencies,
    );
  }

  static FeatureConfig defaultFor(FeatureId id) {
    final promotionFlags = id == FeatureId.offers
        ? <String, Object?>{
            'promotions_enabled': true,
            'banners_enabled': true,
            'offers_enabled': true,
            'discounts_enabled': false,
            'promotion_media_enabled': true,
            'category_targeting_enabled': true,
            'venue_targeting_enabled': true,
            'scheduling_enabled': true,
            'cta_enabled': true,
          }
        : const <String, Object?>{};
    return FeatureConfig(
      enabled: true,
      provider: switch (id) {
        FeatureId.payments || FeatureId.razorpay => 'razorpay',
        FeatureId.maps => 'flutter_map',
        FeatureId.location => 'supabase',
        FeatureId.ai => 'local_intent',
        FeatureId.notifications => 'supabase',
        FeatureId.email => 'outbox',
        FeatureId.whatsapp => 'none',
        FeatureId.barcode => 'qr_check_in',
        _ => null,
      },
      config: promotionFlags,
      dependencies: switch (id) {
        FeatureId.maps => const [FeatureId.location],
        FeatureId.booking => const [FeatureId.location],
        FeatureId.razorpay => const [FeatureId.payments],
        FeatureId.voice => const [FeatureId.search],
        _ => const [],
      },
      optionalDependencies: switch (id) {
        FeatureId.booking => const [FeatureId.payments],
        FeatureId.voice => const [FeatureId.ai],
        _ => const [],
      },
    );
  }
}

class FeatureAvailability {
  const FeatureAvailability({
    required this.enabled,
    required this.available,
    this.missingDependencies = const [],
    this.reason,
  });

  final bool enabled;
  final bool available;
  final List<FeatureId> missingDependencies;
  final String? reason;
}

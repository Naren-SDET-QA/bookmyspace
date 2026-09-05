import '../../../core/modular/feature_id.dart';
import '../../../core/modular/feature_registry.dart';

/// Promotion switches live in the existing Offers FeatureConfig.
class PromotionCapabilities {
  const PromotionCapabilities(this.registry);
  final FeatureRegistry registry;

  bool flag(String key, [bool fallback = true]) =>
      registry.configOf(FeatureId.offers).config[key] as bool? ?? fallback;

  bool get promotionsEnabled => flag('promotions_enabled');
  bool get bannersEnabled => flag('banners_enabled');
  bool get offersEnabled => flag('offers_enabled');
  bool get discountsEnabled => flag('discounts_enabled');
  bool get promotionMediaEnabled => flag('promotion_media_enabled');
  bool get categoryTargetingEnabled => flag('category_targeting_enabled');
  bool get venueTargetingEnabled => flag('venue_targeting_enabled');
  bool get schedulingEnabled => flag('scheduling_enabled');
  bool get ctaEnabled => flag('cta_enabled');
}

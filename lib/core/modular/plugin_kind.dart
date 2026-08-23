import 'feature_id.dart';
import 'feature_registry.dart';

/// Replaceable runtime plugins. Not every repository gets an interface.
enum PluginKind {
  payment,
  map,
  ai,
  notification,
  location,
  voice,
}

extension PluginKindFeature on PluginKind {
  FeatureId get featureId => switch (this) {
    PluginKind.payment => FeatureId.razorpay,
    PluginKind.map => FeatureId.maps,
    PluginKind.ai => FeatureId.ai,
    PluginKind.notification => FeatureId.notifications,
    PluginKind.location => FeatureId.location,
    PluginKind.voice => FeatureId.voice,
  };
}

/// Checkout is available only when both product payments and Razorpay are on.
bool isCheckoutExposed(FeatureRegistry registry) =>
    registry.isExposed(FeatureId.payments) &&
    registry.isExposed(FeatureId.razorpay);

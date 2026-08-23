import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_providers.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  test('featureRegistryProvider rebuilds when configuration changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var notifications = 0;
    container.listen<FeatureRegistry>(
      featureRegistryProvider,
      (previous, next) => notifications++,
      fireImmediately: true,
    );
    expect(notifications, 1);
    expect(container.read(featureRegistryProvider).isExposed(FeatureId.pg), isTrue);

    FeatureRegistry.configure(FeatureId.pg, enabled: false);

    expect(
      container.read(featureRegistryProvider).isExposed(FeatureId.pg),
      isFalse,
    );
    expect(notifications, 2);
  });
}

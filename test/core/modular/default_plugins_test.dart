import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/plugin_kind.dart';
import 'package:bookmyspace/core/modular/plugins/flutter_map_plugin.dart';
import 'package:bookmyspace/core/modular/plugins/payment_checkout_plugin.dart';
import 'package:bookmyspace/core/modular/provider_registry.dart';
import 'package:bookmyspace/core/modular/register_default_plugins.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/payments/mock_payment_repository.dart';

void main() {
  test('default plugins are not constructed until resolve', () {
    var checkoutBuilt = 0;
    var speechBuilt = 0;
    var mapBuilt = 0;
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      checkoutFactory: () {
        checkoutBuilt++;
        return FakeCheckoutService();
      },
      speechFactory: () {
        speechBuilt++;
        throw StateError('speech factory should stay lazy');
      },
      mapFactory: () {
        mapBuilt++;
        return FlutterMapPlugin();
      },
    );

    expect(checkoutBuilt, 0);
    expect(speechBuilt, 0);
    expect(mapBuilt, 0);
    expect(plugins.isInitialized(PluginKind.payment), isFalse);
    expect(plugins.isInitialized(PluginKind.voice), isFalse);
    expect(plugins.isInitialized(PluginKind.map), isFalse);
  });

  test('disabled payment plugin is never constructed', () {
    var checkoutBuilt = 0;
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.payments, enabled: false);
    final plugins = ProviderRegistry(features: features);
    registerDefaultPlugins(
      plugins,
      checkoutFactory: () {
        checkoutBuilt++;
        return FakeCheckoutService();
      },
    );

    expect(plugins.tryResolve(PluginKind.payment), isNull);
    expect(checkoutBuilt, 0);
  });

  test('checkout is unavailable unless payments and razorpay are both exposed', () {
    var checkoutBuilt = 0;
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.razorpay, enabled: false);
    expect(features.isExposed(FeatureId.payments), isTrue);
    expect(features.isExposed(FeatureId.razorpay), isFalse);

    final plugins = ProviderRegistry(features: features);
    registerDefaultPlugins(
      plugins,
      checkoutFactory: () {
        checkoutBuilt++;
        return FakeCheckoutService();
      },
    );

    expect(plugins.tryResolve(PluginKind.payment), isNull);
    expect(checkoutBuilt, 0);
  });

  test('disabled maps plugin factory is never called', () {
    var mapBuilt = 0;
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.maps, enabled: false);
    final plugins = ProviderRegistry(features: features);
    registerDefaultPlugins(
      plugins,
      mapFactory: () {
        mapBuilt++;
        return FlutterMapPlugin();
      },
    );

    expect(plugins.tryResolve(PluginKind.map), isNull);
    expect(mapBuilt, 0);
  });

  test('enabled payment plugin constructs checkout only when needed', () {
    var checkoutBuilt = 0;
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      checkoutFactory: () {
        checkoutBuilt++;
        return FakeCheckoutService();
      },
    );

    final plugin = plugins.resolve(PluginKind.payment) as PaymentCheckoutPlugin;
    expect(checkoutBuilt, 0);
    expect(plugin.checkout, isA<CheckoutService>());
    expect(checkoutBuilt, 1);
    expect(plugin.checkout, isA<CheckoutService>());
    expect(checkoutBuilt, 1);
  });

  test('real plugin factories can be replaced', () async {
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      checkoutFactory: FakeCheckoutService.new,
    );
    final first = plugins.resolve(PluginKind.payment) as PaymentCheckoutPlugin;
    expect(first.checkout, isA<FakeCheckoutService>());

    await plugins.replace(
      PluginKind.payment,
      () => PaymentCheckoutPlugin(
        () => FakeCheckoutService(CheckoutResult.failed),
      ),
    );
    final second = plugins.resolve(PluginKind.payment) as PaymentCheckoutPlugin;
    expect(second.checkout, isA<FakeCheckoutService>());
    expect(identical(first, second), isFalse);
  });

  test('failed optional speech plugin degrades without constructing others', () async {
    var checkoutBuilt = 0;
    final plugins = ProviderRegistry(features: FeatureRegistry.defaults());
    registerDefaultPlugins(
      plugins,
      checkoutFactory: () {
        checkoutBuilt++;
        return FakeCheckoutService();
      },
      speechFactory: () => throw StateError('speech unavailable'),
    );

    expect(plugins.tryResolve(PluginKind.voice), isNotNull);
    await expectLater(
      plugins.ensureInitialized(PluginKind.voice),
      throwsA(isA<StateError>()),
    );
    expect(plugins.isInitialized(PluginKind.voice), isFalse);
    expect(checkoutBuilt, 0);
    expect(plugins.tryResolve(PluginKind.payment), isA<PaymentCheckoutPlugin>());
  });
}

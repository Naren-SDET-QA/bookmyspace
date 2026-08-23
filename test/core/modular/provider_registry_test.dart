import 'package:bookmyspace/core/modular/app_plugin.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/plugin_kind.dart';
import 'package:bookmyspace/core/modular/provider_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlugin implements AppPlugin {
  _FakePlugin(this.id, {this.failTimes = 0});

  @override
  final String id;
  final int failTimes;
  int initializeCalls = 0;
  int disposeCalls = 0;
  bool disposed = false;
  bool _ready = false;

  @override
  bool get initialized => _ready && !disposed;

  @override
  Future<void> ensureInitialized() async {
    initializeCalls++;
    if (initializeCalls <= failTimes) {
      throw StateError('init failed $initializeCalls');
    }
    disposed = false;
    _ready = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    disposed = true;
  }
}

void main() {
  test('provider initialization is lazy', () {
    var built = 0;
    final plugins = ProviderRegistry();
    plugins.register(PluginKind.map, () {
      built++;
      return _FakePlugin('flutter_map');
    });

    expect(plugins.isInitialized(PluginKind.map), isFalse);
    expect(built, 0);

    final plugin = plugins.resolve(PluginKind.map);
    expect(built, 1);
    expect(plugin.id, 'flutter_map');
    expect(plugins.resolve(PluginKind.map), same(plugin));
    expect(built, 1);
  });

  test('disabled feature does not initialize its provider', () {
    final features = FeatureRegistry.defaults()
      ..apply(FeatureId.maps, enabled: false);
    var built = 0;
    final plugins = ProviderRegistry(features: features);
    plugins.register(PluginKind.map, () {
      built++;
      return _FakePlugin('flutter_map');
    });

    expect(plugins.tryResolve(PluginKind.map), isNull);
    expect(built, 0);
    expect(plugins.isInitialized(PluginKind.map), isFalse);
    expect(
      () => plugins.resolve(PluginKind.map),
      throwsA(isA<StateError>()),
    );
    expect(built, 0);
  });

  test('provider can be replaced', () async {
    final plugins = ProviderRegistry();
    plugins.register(PluginKind.payment, () => _FakePlugin('razorpay'));
    final first = plugins.resolve(PluginKind.payment) as _FakePlugin;
    await first.ensureInitialized();

    await plugins.replace(PluginKind.payment, () => _FakePlugin('offline'));
    expect(first.disposeCalls, 1);
    final second = plugins.resolve(PluginKind.payment);
    expect(second.id, 'offline');
    expect(plugins.isInitialized(PluginKind.payment), isFalse);
  });

  test('optional feature failure does not crash the application', () async {
    final plugins = ProviderRegistry();
    plugins.register(PluginKind.ai, () => _FakePlugin('broken', failTimes: 99));

    await expectLater(plugins.ensureInitialized(PluginKind.ai), throwsA(isA<StateError>()));
    expect(plugins.tryResolve(PluginKind.notification), isNull);
    expect(plugins.isInitialized(PluginKind.ai), isFalse);
  });

  test('provider failure can recover safely with bounded retries', () async {
    final plugins = ProviderRegistry();
    plugins.register(PluginKind.location, () => _FakePlugin('geo', failTimes: 2));

    await plugins.ensureInitialized(
      PluginKind.location,
      retry: true,
    );
    final plugin = plugins.resolve(PluginKind.location) as _FakePlugin;
    expect(plugin.initialized, isTrue);
    expect(plugin.initializeCalls, 3);
  });
}

import '../network/retry.dart';
import 'app_plugin.dart';
import 'feature_registry.dart';
import 'plugin_kind.dart';

typedef PluginFactory = AppPlugin Function();

/// Factories only. [resolve] is the first moment a plugin is constructed.
class ProviderRegistry {
  ProviderRegistry({FeatureRegistry? features})
    : _features = features ?? FeatureRegistry.instance;

  final FeatureRegistry _features;
  final Map<PluginKind, PluginFactory> _factories = {};
  final Map<PluginKind, AppPlugin> _instances = {};

  void register(PluginKind kind, PluginFactory factory) {
    _factories[kind] = factory;
  }

  bool isInitialized(PluginKind kind) {
    final plugin = _instances[kind];
    return plugin != null && plugin.initialized;
  }

  AppPlugin? tryResolve(PluginKind kind) {
    if (!_features.isExposed(kind.featureId)) return null;
    final existing = _instances[kind];
    if (existing != null) return existing;
    final factory = _factories[kind];
    if (factory == null) return null;
    final plugin = factory();
    _instances[kind] = plugin;
    return plugin;
  }

  AppPlugin resolve(PluginKind kind) {
    final plugin = tryResolve(kind);
    if (plugin == null) {
      throw StateError('${kind.name} plugin is not available');
    }
    return plugin;
  }

  Future<void> replace(PluginKind kind, PluginFactory factory) {
    final previous = _instances.remove(kind);
    _factories[kind] = factory;
    return previous?.dispose() ?? Future<void>.value();
  }

  Future<void> ensureInitialized(
    PluginKind kind, {
    bool retry = false,
  }) async {
    final plugin = resolve(kind);
    try {
      if (!retry) {
        await plugin.ensureInitialized();
        return;
      }
      await withRetry(
        plugin.ensureInitialized,
        config: const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 20),
        ),
      );
    } catch (error) {
      _instances.remove(kind);
      await plugin.dispose();
      rethrow;
    }
  }
}

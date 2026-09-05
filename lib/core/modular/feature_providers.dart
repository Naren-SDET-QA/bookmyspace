import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_id.dart';
import 'feature_registry.dart';
import 'provider_registry.dart';
import 'register_default_plugins.dart';
import 'plugins/ai_provider_plugin.dart';
import '../../features/auth/presentation/auth_providers.dart';

final _featureRegistryTickProvider = StateProvider<int>((ref) => 0);

final featureRegistryProvider = Provider<FeatureRegistry>((ref) {
  ref.watch(_featureRegistryTickProvider);
  void listener() {
    ref.read(_featureRegistryTickProvider.notifier).state++;
  }

  FeatureRegistry.onChanged = listener;
  ref.onDispose(() {
    if (identical(FeatureRegistry.onChanged, listener)) {
      FeatureRegistry.onChanged = null;
    }
  });
  // A new map so Riverpod treats the value as changed and rebuilds consumers.
  return FeatureRegistry({
    for (final id in FeatureId.values) id: FeatureRegistry.instance.configOf(id),
  });
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  final plugins = ProviderRegistry(
    features: ref.watch(featureRegistryProvider),
  );
  registerDefaultPlugins(
    plugins,
    aiFactory: () => SupabaseAiProvider(ref.read(supabaseProvider)),
  );
  return plugins;
});

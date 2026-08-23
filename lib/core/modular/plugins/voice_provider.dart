import '../app_plugin.dart';
import '../plugin_kind.dart';
import '../provider_registry.dart';

/// Host for the existing `speech_to_text` engine. Not a second speech SDK.
abstract interface class VoiceProvider implements AppPlugin {
  Future<void> listen({
    required String localeId,
    required void Function(String words) onResult,
  });

  Future<void> stop();
}

VoiceProvider? resolvedVoiceProvider(ProviderRegistry registry) {
  final plugin = registry.tryResolve(PluginKind.voice);
  return plugin is VoiceProvider ? plugin : null;
}

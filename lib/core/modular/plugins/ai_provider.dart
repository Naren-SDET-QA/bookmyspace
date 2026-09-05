import '../../../features/ai/domain/ai_provider.dart';
import '../plugin_kind.dart';
import '../provider_registry.dart';

AiProvider? resolvedAiProvider(ProviderRegistry registry) {
  final plugin = registry.tryResolve(PluginKind.ai);
  return plugin is AiProvider ? plugin as AiProvider : null;
}

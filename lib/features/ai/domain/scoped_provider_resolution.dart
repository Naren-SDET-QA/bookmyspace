enum AiProviderScope { global, tenant, category }

class ScopedAiProviderConfig {
  const ScopedAiProviderConfig({
    required this.slug,
    required this.enabled,
    this.priority = 0,
    this.model,
    this.timeoutMs = 10000,
    this.retryCount = 1,
    this.inputLimit = 8000,
    this.outputLimit = 8000,
    this.rateLimit = 20,
  });

  final String slug;
  final bool enabled;
  final int priority;
  final String? model;
  final int timeoutMs;
  final int retryCount;
  final int inputLimit;
  final int outputLimit;
  final int rateLimit;
}

class ScopedAiProviderResolution {
  const ScopedAiProviderResolution({this.primary, this.fallback, this.scope, this.errorCode});

  final ScopedAiProviderConfig? primary;
  final ScopedAiProviderConfig? fallback;
  final AiProviderScope? scope;
  final String? errorCode;

  static ScopedAiProviderResolution resolve({
    Iterable<ScopedAiProviderConfig> global = const [],
    Iterable<ScopedAiProviderConfig> tenant = const [],
    Iterable<ScopedAiProviderConfig> category = const [],
  }) {
    final layers = [
      (AiProviderScope.category, category.toList()),
      (AiProviderScope.tenant, tenant.toList()),
      (AiProviderScope.global, global.toList()),
    ];
    for (final layer in layers) {
      if (layer.$2.isEmpty) continue;
      final enabled = layer.$2.where((config) => config.enabled).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
      if (enabled.isEmpty) return const ScopedAiProviderResolution(errorCode: 'FEATURE_DISABLED');
      return ScopedAiProviderResolution(
        primary: enabled.first,
        fallback: enabled.length > 1 ? enabled[1] : null,
        scope: layer.$1,
      );
    }
    return const ScopedAiProviderResolution(errorCode: 'AI_PROVIDER_NOT_CONFIGURED');
  }
}

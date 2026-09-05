class AiProviderConfig {
  const AiProviderConfig({
    required this.slug,
    required this.enabled,
    this.priority = 0,
    int timeoutMs = 10000,
    int retryCount = 1,
    int maxInput = 8000,
    int maxOutput = 8000,
    int rateLimit = 20,
  })  : timeoutMs = timeoutMs > 30000 ? 30000 : timeoutMs < 1000 ? 1000 : timeoutMs,
        retryCount = retryCount > 3 ? 3 : retryCount < 0 ? 0 : retryCount,
        maxInput = maxInput > 16000 ? 16000 : maxInput < 256 ? 256 : maxInput,
        maxOutput = maxOutput > 16000 ? 16000 : maxOutput < 256 ? 256 : maxOutput,
        rateLimit = rateLimit > 60 ? 60 : rateLimit < 1 ? 1 : rateLimit;

  final String slug;
  final bool enabled;
  final int priority;
  final int timeoutMs;
  final int retryCount;
  final int maxInput;
  final int maxOutput;
  final int rateLimit;
}

class AiProviderResolution {
  const AiProviderResolution({this.primary, this.fallback, this.errorCode});

  final AiProviderConfig? primary;
  final AiProviderConfig? fallback;
  final String? errorCode;

  static AiProviderResolution resolve(Iterable<AiProviderConfig> configs) {
    final enabled = configs.where((config) => config.enabled).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    if (enabled.isEmpty) {
      return const AiProviderResolution(errorCode: 'AI_PROVIDER_NOT_CONFIGURED');
    }
    return AiProviderResolution(
      primary: enabled.first,
      fallback: enabled.length > 1 ? enabled[1] : null,
    );
  }
}

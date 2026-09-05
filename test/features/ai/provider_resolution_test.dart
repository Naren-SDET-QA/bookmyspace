import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/provider_resolution.dart';

void main() {
  test('selects the highest-priority enabled AI provider', () {
    final result = AiProviderResolution.resolve([
      const AiProviderConfig(slug: 'fallback', enabled: true, priority: 2),
      const AiProviderConfig(slug: 'primary', enabled: true, priority: 10),
      const AiProviderConfig(slug: 'disabled', enabled: false, priority: 99),
    ]);

    expect(result.primary?.slug, 'primary');
    expect(result.fallback?.slug, 'fallback');
  });

  test('returns not configured when no enabled provider exists', () {
    final result = AiProviderResolution.resolve([
      const AiProviderConfig(slug: 'disabled', enabled: false),
    ]);

    expect(result.errorCode, 'AI_PROVIDER_NOT_CONFIGURED');
  });

  test('limits are bounded even when configuration is excessive', () {
    const config = AiProviderConfig(
      slug: 'local',
      enabled: true,
      timeoutMs: 999999,
      retryCount: 99,
      maxInput: 999999,
      maxOutput: 999999,
      rateLimit: 999999,
    );

    expect(config.timeoutMs, lessThanOrEqualTo(30000));
    expect(config.retryCount, lessThanOrEqualTo(3));
    expect(config.maxInput, lessThanOrEqualTo(16000));
    expect(config.maxOutput, lessThanOrEqualTo(16000));
    expect(config.rateLimit, lessThanOrEqualTo(60));
  });
}

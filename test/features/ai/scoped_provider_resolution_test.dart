import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/scoped_provider_resolution.dart';

void main() {
  test('category overrides tenant and global configuration', () {
    final result = ScopedAiProviderResolution.resolve(
      global: const [ScopedAiProviderConfig(slug: 'global', enabled: true, priority: 1)],
      tenant: const [ScopedAiProviderConfig(slug: 'tenant', enabled: true, priority: 2)],
      category: const [ScopedAiProviderConfig(slug: 'category', enabled: true, priority: 3)],
    );

    expect(result.primary?.slug, 'category');
    expect(result.scope, AiProviderScope.category);
  });

  test('empty category falls back to tenant, then global', () {
    final result = ScopedAiProviderResolution.resolve(
      global: const [ScopedAiProviderConfig(slug: 'global', enabled: true)],
      tenant: const [ScopedAiProviderConfig(slug: 'tenant', enabled: true)],
    );

    expect(result.primary?.slug, 'tenant');
    expect(result.scope, AiProviderScope.tenant);
  });

  test('disabled effective configuration reports feature disabled', () {
    final result = ScopedAiProviderResolution.resolve(
      global: const [ScopedAiProviderConfig(slug: 'global', enabled: true)],
      category: const [ScopedAiProviderConfig(slug: 'category', enabled: false)],
    );

    expect(result.errorCode, 'FEATURE_DISABLED');
  });
}

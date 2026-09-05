import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/ai_chat_coordinator.dart';
import 'package:bookmyspace/features/ai/domain/ai_provider.dart';

class _Provider extends AiProvider {
  _Provider(this.payload);
  final String payload;

  @override
  String get id => 'test';

  @override
  Future<AiProviderResponse> generateResponse(AiProviderRequest request) async =>
      AiProviderResponse(text: payload, providerId: id);

  @override
  Future<bool> healthCheck() async => true;
}

void main() {
  test('coordinator returns an intent without executing protected actions', () async {
    final coordinator = AiChatCoordinator(provider: _Provider('{"intent":"SEARCH","category":"sports_court"}'));

    final result = await coordinator.interpret('Find a sports court');

    expect(result.errorCode, isNull);
    expect(result.intent?.category, 'sports_court');
    expect(result.requiresActionGate, isTrue);
    expect(result.actionExecuted, isFalse);
  });

  test('provider failure degrades to manual fallback', () async {
    final coordinator = AiChatCoordinator(provider: _FailingProvider());

    final result = await coordinator.interpret('Book something');

    expect(result.errorCode, 'AI_PROVIDER_UNAVAILABLE');
    expect(result.manualFallback, isTrue);
  });
}

class _FailingProvider extends AiProvider {
  @override
  String get id => 'failing';

  @override
  Future<AiProviderResponse> generateResponse(AiProviderRequest request) =>
      Future.error(const AiProviderException('offline'));

  @override
  Future<bool> healthCheck() async => false;
}

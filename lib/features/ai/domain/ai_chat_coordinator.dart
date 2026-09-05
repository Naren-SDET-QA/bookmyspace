import 'ai_provider.dart';
import 'universal_intent.dart';

/// Bridges provider output to the existing clarification/action-gate pipeline.
/// It deliberately has no method that executes a business action.
class AiChatCoordinator {
  const AiChatCoordinator({required this.provider});

  final AiProvider provider;

  Future<AiChatInterpretation> interpret(
    String input, {
    String locale = 'en',
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final structured = await provider.generateStructuredIntent(
        AiProviderRequest(input: input, locale: locale, context: context),
      );
      if (structured.errorCode != null || structured.intent == null) {
        return AiChatInterpretation(
          errorCode: structured.errorCode ?? 'INVALID_AI_RESPONSE',
          manualFallback: true,
        );
      }
      return AiChatInterpretation(
        intent: structured.intent,
        providerId: structured.providerId,
        requiresActionGate: true,
      );
    } on AiProviderException {
      return const AiChatInterpretation(
        errorCode: 'AI_PROVIDER_UNAVAILABLE',
        manualFallback: true,
      );
    } catch (_) {
      return const AiChatInterpretation(
        errorCode: 'AI_PROVIDER_UNAVAILABLE',
        manualFallback: true,
      );
    }
  }
}

class AiChatInterpretation {
  const AiChatInterpretation({
    this.intent,
    this.providerId,
    this.errorCode,
    this.requiresActionGate = false,
    this.actionExecuted = false,
    this.manualFallback = false,
  });

  final UniversalIntent? intent;
  final String? providerId;
  final String? errorCode;
  final bool requiresActionGate;
  final bool actionExecuted;
  final bool manualFallback;
}

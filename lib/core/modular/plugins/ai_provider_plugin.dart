import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/ai/domain/ai_provider.dart';
import '../app_plugin.dart';

/// Provider-neutral client boundary for the server-authoritative ai-chat
/// function. It contains no provider credentials or business mutations.
class SupabaseAiProvider extends AiProvider implements AppPlugin {
  SupabaseAiProvider(this._client);

  final SupabaseClient _client;

  @override
  String get id => 'server-ai';

  @override
  bool get initialized => true;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<AiProviderResponse> generateResponse(AiProviderRequest request) async {
    try {
      final response = await _client.functions.invoke(
        'ai-chat',
        body: {
          'input': request.input,
          'locale': request.locale,
          'context': request.context,
        },
      );
      final data = response.data;
      if (data is! Map) throw const AiProviderException('AI provider unavailable');
      final payload = Map<String, dynamic>.from(data);
      if (payload['error_code'] != null) {
        throw AiProviderException(payload['error_code'].toString());
      }
      final nested = payload['data'];
      final intent = nested is Map ? nested['intent'] : null;
      if (intent is! Map) throw const AiProviderException('Invalid AI response');
      return AiProviderResponse(
        text: jsonEncode(intent),
        providerId: nested['provider']?.toString() ?? id,
        model: nested['model']?.toString(),
      );
    } on AiProviderException {
      rethrow;
    } catch (_) {
      throw const AiProviderException('AI provider unavailable');
    }
  }

}

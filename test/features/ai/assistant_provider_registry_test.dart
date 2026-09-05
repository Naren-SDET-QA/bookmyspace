import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AssistantScreen resolves AI through ProviderRegistry', () {
    final source = File('lib/features/ai/presentation/screens/assistant_screen.dart').readAsStringSync();
    expect(source, contains('resolvedAiProvider'));
    expect(source, isNot(contains('AiChatCoordinator(provider: LocalAiProvider())')));
  });

  test('default provider registration includes the AI plugin factory', () {
    final source = File('lib/core/modular/register_default_plugins.dart').readAsStringSync();
    expect(source, contains('PluginKind.ai'));
    expect(source, contains('aiFactory'));
  });
}

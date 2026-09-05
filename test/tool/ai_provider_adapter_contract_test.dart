import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server AI adapter reuses integration security policy', () {
    final source = File('supabase/functions/_shared/ai_provider_adapter.ts').readAsStringSync();
    expect(source, contains("executor_policy.ts"));
    expect(source, contains('ServerAiProviderAdapter'));
    expect(source, contains('LocalAiProviderAdapter'));
    expect(source, contains('redactSensitive'));
    expect(source, contains('buildRequestUrl'));
    expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });
}

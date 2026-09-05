import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI observability emitter is safe, bounded, and non-authoritative', () {
    final source = File('supabase/functions/_shared/ai_observability.ts').readAsStringSync();
    expect(source, contains('emitAiEvent'));
    expect(source, contains('AI_EVENTS'));
    expect(source, contains('redactSensitive'));
    expect(source, contains('catch'));
    expect(source, contains('Promise<void>'));
    expect(source, contains("from('error_events')"));
    expect(source, isNot(contains('authorization')));
    expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(source, contains('slice(0, 120)'));
  });
}

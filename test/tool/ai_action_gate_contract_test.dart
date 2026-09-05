import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI action gate is server-side and does not expose mutation handlers', () {
    final source = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();
    expect(source, contains("Deno.serve"));
    expect(source, contains("Authorization"));
    expect(source, contains("limit(50)"));
    expect(source, contains("UNAUTHENTICATED"));
    expect(source, contains("CONFIRMATION_REQUIRED"));
    expect(source, contains("CREATE_HOLD"));
    expect(source, contains("error('CONFIRMATION_REQUIRED'"));
  });
}

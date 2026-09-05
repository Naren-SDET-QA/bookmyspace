import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server clarification function is authenticated and session scoped', () {
    final source = File('supabase/functions/ai-clarification/index.ts').readAsStringSync();
    expect(source, contains("Authorization"));
    expect(source, contains("eq('user_id', user.id)"));
    expect(source, contains('START_CLARIFICATION'));
    expect(source, contains('SUBMIT_ANSWER'));
    expect(source, contains('CATEGORY_CLARIFICATION_REQUIRED'));
    expect(source, contains('INVALID_FIELD'));
    expect(source, contains('expires_at'));
    expect(source, contains("clarification_expired"));
    expect(source, contains("neq('state', 'EXPIRED')"));
  });
}

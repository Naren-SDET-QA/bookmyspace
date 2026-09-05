import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI category activation uses the existing metadata configuration', () {
    final clarification = File('supabase/functions/ai-clarification/index.ts').readAsStringSync();
    final actionGate = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();
    expect(clarification, contains("select('id,slug,name,metadata')"));
    expect(actionGate, contains("select('metadata')"));
    expect(clarification, contains("metadata.active !== false"));
    expect(actionGate, contains("metadata.active"));
    expect(clarification, isNot(contains('select(\'id,slug,name,active,metadata\')')));
    expect(actionGate, isNot(contains(".eq('active', true)")));
  });
}

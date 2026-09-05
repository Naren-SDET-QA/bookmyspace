import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ai-chat authenticates and returns an action-gate handoff', () {
    final source = File('supabase/functions/ai-chat/index.ts').readAsStringSync();
    expect(source, contains("auth.getUser()"));
    expect(source, contains("action_gate_required: true"));
    expect(source, contains("from('venues')"));
    expect(source, contains("organization_configurations"));
    expect(source, contains("organization_category_configurations"));
    expect(source, isNot(contains("body.tenant_id")));
    expect(source, isNot(contains("body.organization_id")));
    expect(source, contains("AI_RATE_LIMITED"));
    expect(source, contains("AI_PROVIDER_UNAVAILABLE"));
    expect(source, contains("Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')"));
    expect(source, contains("action_gate_required: true"));
  });
}

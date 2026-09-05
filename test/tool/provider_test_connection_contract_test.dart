import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider test connection exposes only safe result statuses', () {
    final source = File('supabase/functions/integration-executor/index.ts').readAsStringSync();
    expect(source, contains("{ status: 'SUCCESS' }"));
    expect(source, contains("{ status: 'SAFE_ERROR' }"));
    expect(source, isNot(contains('reason: `http_')));
    expect(source, isNot(contains("reason: 'integration_unavailable'")));
  });
}

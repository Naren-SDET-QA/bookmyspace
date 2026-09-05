import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('circuit migration reuses recovery state with bounded atomic RPCs', () {
    final source = File('supabase/migrations/20260825103000_ai_circuit_rpc_local.sql').readAsStringSync();
    expect(source, contains('observability_recovery_state'));
    expect(source, contains('ai_circuit_admit'));
    expect(source, contains('ai_circuit_record_result'));
    expect(source, contains('for update'));
    expect(source, contains("'CIRCUIT_OPEN'"));
    expect(source, contains("'RECOVERING'"));
    expect(source, contains('next_retry_at'));
    expect(source, contains('security definer'));
    expect(source, contains('set search_path = public, pg_catalog'));
    expect(source, isNot(contains('bookings')));
    expect(source, isNot(contains('payments')));
  });
}

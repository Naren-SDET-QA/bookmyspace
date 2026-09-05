import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated clarification observability can insert events', () {
    final source = File(
      'supabase/migrations/20260825110000_ai_observability_insert_grant_local.sql',
    ).readAsStringSync();
    expect(source, contains('grant insert on public.analytics_events to authenticated'));
    expect(source, isNot(contains('grant select on public.analytics_events to anon')));
  });
}

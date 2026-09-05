import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI rate limit migration is atomic, bounded, and server-side', () {
    final source = File('supabase/migrations/20260825100000_ai_rate_limit_local.sql').readAsStringSync();
    expect(source, contains('create table if not exists public.ai_request_rate_limits'));
    expect(source, contains('create or replace function public.consume_ai_rate_limit'));
    expect(source, contains('pg_advisory_xact_lock'));
    expect(source, contains('security definer'));
    expect(source, contains('auth.uid()'));
    expect(source, contains('check (request_count >= 0)'));
    expect(source, isNot(contains('bookings')));
    expect(source, isNot(contains('payments')));
  });
}

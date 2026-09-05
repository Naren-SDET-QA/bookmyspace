import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosted Supabase values are supplied through dart-defines', () {
    final source = File('lib/core/config/app_config.dart').readAsStringSync();

    expect(source, contains("'SUPABASE_URL'"));
    expect(source, contains("'SUPABASE_ANON_KEY'"));
    expect(source, isNot(contains('zykxneztahxbjduagutv.supabase.co')));
    expect(source, isNot(contains('ehxuygrsyaknhhsaihhx.supabase.co')));
    expect(source, isNot(contains('sb_publishable_')));
  });
}

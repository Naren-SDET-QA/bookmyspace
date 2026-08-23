import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEV E2E seed is guarded, deterministic, and covers the fixture contract', () {
    final sql = File('supabase/seed_dev_e2e.sql').readAsStringSync();

    expect(sql, contains('bms_dev'));
    expect(sql, contains('bms_project_ref'));
    expect(sql, contains('zykxneztahxbjduagutv'));
    expect(sql, contains('e2e_v1'));
    expect(sql, contains('generate_series(1, 10)'));
    expect(sql, contains('on conflict'));
    expect(sql, contains('location_node_id'));
    expect(sql, contains('synthetic_fixture'));
    expect(sql, contains('registration_required'));
    expect(sql, contains('kyc_required'));
    expect(sql, contains('invoice_documents'));
    expect(sql, contains('booking_check_ins'));
    expect(sql, contains('email_outbox'));
    expect(sql, contains('refunds'));
    expect(sql, contains('coupons'));
    expect(sql, contains('auth.users'));
    expect(sql.toLowerCase(), isNot(contains('drop table')));
    expect(sql.toLowerCase(), isNot(contains('truncate')));
    expect(RegExp(r"insert\s+into\s+auth\.users", caseSensitive: false).hasMatch(sql), isFalse);
  });

  test('SQL Editor seed and verification contain PostgreSQL only', () {
    final seed = File('supabase/seed_dev_e2e_sql_editor.sql').readAsStringSync();
    final verify = File('supabase/tests/dev_e2e_seed_verify_sql_editor.sql').readAsStringSync();
    expect(seed, contains('zykxneztahxbjduagutv'));
    expect(seed, contains('bms-dev-e2e-function_hall-'));
    expect(seed, contains('for v_family in 1..4'));
    expect(seed.toLowerCase(), isNot(contains('\\if')));
    expect(seed.toLowerCase(), isNot(contains('\\echo')));
    expect(seed.toLowerCase(), isNot(contains('delete from')));
    expect(seed.toLowerCase(), isNot(contains('truncate')));
    expect(seed.toLowerCase(), isNot(contains('drop table')));
    expect(seed.toLowerCase(), isNot(contains('insert into auth.users')));
    expect(verify, contains('select c.slug'));
    expect(verify.toLowerCase(), isNot(contains('insert')));
    expect(verify.toLowerCase(), isNot(contains('update')));
    expect(verify.toLowerCase(), isNot(contains('delete')));
  });
}

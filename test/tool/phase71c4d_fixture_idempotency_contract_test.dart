import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated local E2E hotel slot fixture is idempotent', () {
    final source = File(
      'scripts/phase71c4d_authenticated_local_e2e.ps1',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'insert into time_slots(id,venue_id,label,start_time,end_time,price_amount,is_active)',
      ),
    );
    expect(source, contains('on conflict (id) do update'));
    expect(source, contains('price_amount=excluded.price_amount'));
  });
}

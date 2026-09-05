import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET_OFFER queries active, currently valid coupons with a bounded result', () {
    final source = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();

    expect(source, contains("action === 'GET_OFFER'"));
    expect(source, contains("from('coupons')"));
    expect(source, contains("eq('is_active', true)"));
    expect(source, contains("limit(limit)"));
    expect(source, isNot(contains("return json({ action, offers: [] })")));
  });
}

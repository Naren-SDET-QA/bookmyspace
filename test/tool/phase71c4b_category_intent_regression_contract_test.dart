import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 7.1-C harness uses supported categories and authoritative availability', () {
    final source = File('scripts/phase71c4b_category_intent_regression.ps1').readAsStringSync();
    for (final value in ['PHASE71_TEST_', 'hotel', 'temple', 'function hall', 'pg', 'institute', 'class', 'sports court', 'sports_ground']) {
      expect(source, contains(value));
    }
    for (final intent in ['SEARCH', 'AVAILABILITY', 'RESOURCE_DETAILS', 'BOOKING', 'GET_OFFER', 'BOOKING_PREVIEW', 'CONFIRMATION_REQUIRED']) {
      expect(source, contains(intent));
    }
    expect(source, contains('available_time_slots'));
    expect(source, contains('CATEGORY_CONTRACT_MISSING'));
    expect(source, contains('finally'));
    expect(source, contains('auth.users where id'));
    expect(source, isNot(contains('time_slots?')));
    expect(source, isNot(contains('slot_date')));
    expect(source, isNot(contains('CONFIRM_BOOKING')));
    expect(source, isNot(contains('CREATE_HOLD')));
    expect(source, isNot(contains('REFUND_REQUEST')));
  });
}

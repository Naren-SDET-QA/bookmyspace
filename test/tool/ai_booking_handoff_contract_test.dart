import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking handoff is a confirmed, read-only server boundary', () {
    final source = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();
    expect(source, contains("'BOOKING_HANDOFF'"));
    expect(source, contains("action === 'BOOKING_HANDOFF'"));
    expect(source, contains("body.confirmed !== true"));
    expect(source, contains("rpc('available_time_slots'"));
      expect(source, contains("from('venues')"));
      expect(source, contains("category_id: venue.category_id"));
      expect(source, isNot(contains("price: preview")));
      expect(source, isNot(contains("total: preview")));
      expect(source, isNot(contains("tax: preview")));
      expect(source, isNot(contains("from('bookings').insert")));
  });

  test('handoff never trusts client authoritative identity or pricing fields', () {
    final source = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();
    final handoff = source.substring(
      source.indexOf("if (action === 'BOOKING_HANDOFF')"),
      source.indexOf("if (action === 'SEARCH')"),
    );
    for (final field in [
      'user_id',
      'tenant_id',
      'organization_id',
      'resource_id',
      'price',
      'tax',
      'total',
      'permissions',
    ]) {
      expect(handoff, isNot(contains("body.$field")), reason: field);
    }
    expect(handoff, contains('userId'), reason: 'authenticated user context');
    expect(handoff, contains("from('venues')"));
    expect(source, contains("rpc('available_time_slots'"));
  });

  test('handoff revalidates the exact live resource, venue and date', () {
    final source = File('supabase/functions/ai-action-gate/index.ts').readAsStringSync();
    expect(source, contains("rpc('available_time_slots'"));
    expect(source, contains("p_venue_id: String(venueId)"));
    expect(source, contains('p_book_date: date'));
    expect(source, contains("if (!venue || !slot) return error('SLOT_UNAVAILABLE', 409)"));
    expect(source, isNot(contains("slot_date")));
    expect(source, isNot(contains("time_slots').select")));
  });
}

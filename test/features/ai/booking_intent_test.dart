import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/ai/domain/booking_intent.dart';

void main() {
  const parser = BookingIntentParser();
  final now = DateTime(2026, 8, 20, 10);

  test('extracts section, location, capacity and budget', () {
    final intent = parser.parse(
      'I need a function hall in Hyderabad for 200 people under 30,000',
      now: now,
    );
    expect(intent.category, 'function_halls');
    expect(intent.location, 'Hyderabad');
    expect(intent.guests, 200);
    expect(intent.budget, 30000);
  });

  test('extracts tomorrow and stay duration', () {
    final intent = parser.parse(
      'Find a hotel room in Hyderabad tomorrow for 2 nights',
      now: now,
    );
    expect(intent.category, 'lodge_rooms');
    expect(intent.date, DateTime(2026, 8, 21));
    expect(intent.nights, 2);
  });

  test('ambiguous input never becomes a booking action', () {
    final intent = parser.parse('please help me', now: now);
    expect(intent.hasSearchSignal, isFalse);
  });
}

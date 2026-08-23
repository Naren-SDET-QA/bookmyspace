import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Booking booking({
    required String id,
    required DateTime date,
    BookingStatus status = BookingStatus.confirmed,
  }) {
    return Booking(
      id: id,
      bookingRef: id,
      venueId: 'v1',
      slotId: 's1',
      bookDate: date,
      startTime: '09:00:00',
      endTime: '11:00:00',
      status: status,
      amount: 1000,
      taxAmount: 180,
      totalAmount: 1180,
    );
  }

  test('groups bookings by calendar day', () {
    final grouped = OwnerBookingCalendar.groupByDate([
      booking(id: 'a', date: DateTime(2026, 8, 22, 10)),
      booking(id: 'b', date: DateTime(2026, 8, 22, 18)),
      booking(id: 'c', date: DateTime(2026, 8, 23)),
    ]);
    expect(grouped, hasLength(2));
    expect(
      grouped[OwnerBookingCalendar.dayKey(DateTime(2026, 8, 22))]!.map((b) => b.id),
      ['a', 'b'],
    );
  });

  test('confirmed count excludes cancelled holds', () {
    final count = OwnerBookingCalendar.confirmedCount([
      booking(id: 'a', date: DateTime(2026, 8, 22), status: BookingStatus.confirmed),
      booking(id: 'b', date: DateTime(2026, 8, 22), status: BookingStatus.held),
      booking(id: 'c', date: DateTime(2026, 8, 22), status: BookingStatus.cancelled),
    ]);
    expect(count, 1);
  });
}

import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/customer_analytics/domain/customer_analytics.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _booking(String id, BookingStatus status, DateTime created) => Booking(
  id: id,
  bookingRef: id,
  venueId: 'v',
  slotId: 's',
  bookDate: created,
  startTime: '09:00',
  endTime: '10:00',
  status: status,
  amount: 100,
  taxAmount: 0,
  totalAmount: 100,
  createdAt: created,
);
Payment _payment(String bookingId, PaymentStatus status, double amount) =>
    Payment(
      id: bookingId,
      bookingId: bookingId,
      amount: amount,
      currency: 'INR',
      status: status,
    );

void main() {
  test('aggregates spending, booking statuses and months', () {
    final result = CustomerAnalytics.fromData(
      payments: [
        _payment('a', PaymentStatus.captured, 100),
        _payment('b', PaymentStatus.refunded, 50),
      ],
      bookings: [
        _booking('a', BookingStatus.completed, DateTime(2026, 1, 10)),
        _booking('b', BookingStatus.refunded, DateTime(2026, 2, 10)),
        _booking('c', BookingStatus.cancelled, DateTime(2026, 2, 11)),
      ],
    );
    expect(result.spent, 50);
    expect(result.bookings, 3);
    expect(result.completed, 1);
    expect(result.refunded, 1);
    expect(result.cancelled, 1);
    expect(result.monthly['2026-01'], 100);
    expect(result.monthly['2026-02'], -50);
  });

  test('date filtering excludes bookings outside the range', () {
    final result = CustomerAnalytics.fromData(
      payments: [
        _payment('a', PaymentStatus.captured, 100),
        _payment('b', PaymentStatus.captured, 200),
      ],
      bookings: [
        _booking('a', BookingStatus.confirmed, DateTime(2026, 1, 10)),
        _booking('b', BookingStatus.confirmed, DateTime(2026, 3, 10)),
      ],
      start: DateTime(2026, 2),
      end: DateTime(2026, 2, 28),
    );
    expect(result.bookings, 0);
    expect(result.spent, 0);
  });

  test(
    'analytics only includes payments belonging to selected customer bookings',
    () {
      final result = CustomerAnalytics.fromData(
        payments: [
          _payment('mine', PaymentStatus.captured, 75),
          _payment('other', PaymentStatus.captured, 999),
        ],
        bookings: [_booking('mine', BookingStatus.confirmed, DateTime(2026))],
      );
      expect(result.spent, 75);
      expect(result.recent.single.bookingId, 'mine');
    },
  );
}

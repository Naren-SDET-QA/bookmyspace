import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimeSlot', () {
    test('parses db row and trims times for display', () {
      final slot = TimeSlot.fromJson({
        'id': 's1',
        'venue_id': 'v1',
        'label': 'Morning',
        'start_time': '09:00:00',
        'end_time': '13:00:00',
        'price_amount': 35000,
        'is_active': true,
      });

      expect(slot.id, 's1');
      expect(slot.displayStart, '09:00');
      expect(slot.displayEnd, '13:00');
      expect(slot.priceAmount, 35000);
    });
  });

  group('SlotAvailability', () {
    test('maps availability and reason', () {
      final avail = SlotAvailability.fromJson({
        'slot_id': 's1',
        'label': 'Morning',
        'start_time': '09:00:00',
        'end_time': '13:00:00',
        'price_amount': 35000,
        'is_available': false,
        'reason': 'booked',
      });

      expect(avail.isAvailable, isFalse);
      expect(avail.reason, 'booked');
      expect(avail.displayStart, '09:00');
    });
  });

  group('BookingStatus', () {
    test('round-trips db values', () {
      for (final status in BookingStatus.values) {
        expect(BookingStatus.fromDb(status.dbValue), status);
      }
    });

    test('unknown status falls back to pending', () {
      expect(BookingStatus.fromDb('weird'), BookingStatus.pending);
    });
  });

  group('Booking', () {
    test('parses a booking with joined venue and slot', () {
      final booking = Booking.fromJson({
        'id': 'b1',
        'booking_ref': 'BMS-1A2B3C',
        'venue_id': 'v1',
        'slot_id': 's1',
        'book_date': '2026-09-01',
        'start_time': '09:00:00',
        'end_time': '13:00:00',
        'status': 'confirmed',
        'amount': 35000,
        'tax_amount': 6300,
        'total_amount': 41300,
        'venues': {'id': 'v1', 'name': 'Sunrise', 'city': 'Hyderabad'},
        'time_slots': {'id': 's1', 'label': 'Morning'},
      });

      expect(booking.bookingRef, 'BMS-1A2B3C');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.venueName, 'Sunrise');
      expect(booking.slotLabel, 'Morning');
      expect(booking.isActive, isTrue);
      expect(booking.canCancel, isFalse);
    });

    test('only pending bookings can be cancelled', () {
      expect(Booking.fromJson({'status': 'pending'}).canCancel, isTrue);
      expect(Booking.fromJson({'status': 'confirmed'}).canCancel, isFalse);
    });

    test('parses metadata and payment embed for offline bookings', () {
      final booking = Booking.fromJson({
        'id': 'b2',
        'booking_ref': 'BMS-ABCDEF',
        'status': 'confirmed',
        'metadata': {
          'offline_booking': true,
          'customer_name': 'Ravi Kumar',
          'customer_phone': '9876543210',
        },
        'payments': {
          'method': 'offline',
          'provider_payment_id': 'OFF-001',
          'status': 'captured',
          'created_at': '2026-08-18T10:30:00Z',
        },
      });

      expect(booking.isOffline, isTrue);
      expect(booking.customerName, 'Ravi Kumar');
      expect(booking.customerPhone, '9876543210');
      expect(booking.paymentMethod, 'offline');
      expect(booking.paymentRef, 'OFF-001');
      expect(booking.paidAt, DateTime.parse('2026-08-18T10:30:00Z'));
      expect(booking.canViewInvoice, isTrue);
    });

    test('online bookings with no payment embed are not marked paid', () {
      final booking = Booking.fromJson({'id': 'b3', 'status': 'confirmed'});
      expect(booking.isOffline, isFalse);
      expect(booking.paymentMethod, isEmpty);
      expect(booking.paidAt, isNull);
      expect(booking.canViewInvoice, isTrue);
    });

    test('pending bookings cannot view an invoice', () {
      final booking = Booking.fromJson({
        'id': 'b4',
        'status': 'pending',
        'payments': {
          'method': 'offline',
          'provider_payment_id': 'OFF-002',
          'status': 'pending',
        },
      });
      expect(booking.canViewInvoice, isFalse);
    });

    test('lifecycle status flags match payment and invoice boundaries', () {
      final statuses = <BookingStatus, ({bool active, bool invoice, bool refund})>{
        BookingStatus.held: (active: true, invoice: false, refund: false),
        BookingStatus.pending: (active: true, invoice: false, refund: false),
        BookingStatus.confirmed: (active: true, invoice: true, refund: true),
        BookingStatus.completed: (active: false, invoice: true, refund: false),
        BookingStatus.cancelled: (active: false, invoice: false, refund: false),
        BookingStatus.refunded: (active: false, invoice: true, refund: false),
        BookingStatus.noShow: (active: false, invoice: true, refund: false),
      };
      for (final entry in statuses.entries) {
        final booking = _mockBooking(entry.key);
        expect(booking.isActive, entry.value.active, reason: entry.key.name);
        expect(booking.canViewInvoice, entry.value.invoice, reason: entry.key.name);
        expect(booking.canRefund, entry.value.refund, reason: entry.key.name);
      }
    });
  });

  group('BookingHold', () {
    test('computes expiry from expires_in_minutes', () {
      final hold = BookingHold.fromResponse({
        'hold_id': 'hold-1',
        'expires_in_minutes': 5,
      });
      expect(hold.id, 'hold-1');
      expect(hold.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });
}

Booking _mockBooking(BookingStatus status) => Booking(
  id: 'lifecycle-${status.name}',
  bookingRef: 'BMS-LIFE',
  venueId: 'v1',
  slotId: 's1',
  bookDate: DateTime(2026, 9, 1),
  startTime: '09:00:00',
  endTime: '10:00:00',
  status: status,
  amount: 100,
  taxAmount: 18,
  totalAmount: 118,
);

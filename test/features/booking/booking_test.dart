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

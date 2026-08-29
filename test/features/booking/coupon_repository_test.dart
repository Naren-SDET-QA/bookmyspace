import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_booking_repository.dart';

/// Exercises promo-code application against [MockBookingRepository], which
/// intentionally mirrors the same rules as the `apply_booking_coupon` /
/// `remove_booking_coupon` Postgres functions (Phase 17 migration) — same
/// error codes, same discount math, same idempotency behaviour. Flutter/dart
/// tooling is unavailable in this workspace to run these against a live
/// Supabase instance, so this is the closest verifiable proxy for the
/// server-side contract; the SQL itself should additionally be exercised
/// against a real (dev) database per the report.
Booking _pendingBooking({
  String id = 'b1',
  double amount = 35000,
  double taxAmount = 6300,
  BookingStatus status = BookingStatus.pending,
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-1A2B3C',
    venueId: 'v1',
    slotId: 's1',
    bookDate: DateTime(2026, 9, 1),
    startTime: '09:00:00',
    endTime: '13:00:00',
    status: status,
    amount: amount,
    taxAmount: taxAmount,
    totalAmount: amount + taxAmount,
    venueName: 'Sunrise Function Hall',
    slotLabel: 'Morning',
  );
}

void main() {
  group('applyCoupon — valid codes', () {
    test('percentage discount is computed server-side from base+tax', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      final updated = await repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10');

      // base = 35000 + 6300 = 41300; 10% = 4130 (under the 5000 cap).
      expect(updated.discountAmount, 4130);
      expect(updated.totalAmount, 41300 - 4130);
    });

    test('fixed discount is applied as-is', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(amount: 10000, taxAmount: 0)],
      );
      final updated = await repo.applyCoupon(bookingId: 'b1', code: 'FESTIVE500');

      expect(updated.discountAmount, 500);
      expect(updated.totalAmount, 9500);
    });

    test('a percentage discount is capped at max_discount_amount', () async {
      // base = 100000; 10% would be 10000, capped to WELCOME10's 5000 cap.
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(amount: 100000, taxAmount: 0)],
      );
      final updated = await repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10');

      expect(updated.discountAmount, 5000);
      expect(updated.totalAmount, 95000);
    });

    test('lowercase / stray whitespace input still matches the code', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      final updated = await repo.applyCoupon(bookingId: 'b1', code: '  welcome10 ');

      expect(updated.discountAmount, 4130);
    });
  });

  group('applyCoupon — rejections', () {
    test('an unknown code is rejected', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      await expectLater(
        repo.applyCoupon(bookingId: 'b1', code: 'NOPE123'),
        throwsA(
          isA<BusinessException>().having((e) => e.code, 'code', 'coupon_not_found'),
        ),
      );
    });

    test('an inactive code is rejected', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      await expectLater(
        repo.applyCoupon(bookingId: 'b1', code: 'INACTIVE_TEST'),
        throwsA(
          isA<BusinessException>().having((e) => e.code, 'code', 'coupon_inactive'),
        ),
      );
    });

    test('an expired code is rejected', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      await expectLater(
        repo.applyCoupon(bookingId: 'b1', code: 'EXPIRED_TEST'),
        throwsA(
          isA<BusinessException>().having((e) => e.code, 'code', 'coupon_expired'),
        ),
      );
    });

    test('a booking below the minimum amount is rejected', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(amount: 2000, taxAmount: 0)],
      );
      await expectLater(
        repo.applyCoupon(bookingId: 'b1', code: 'MIN5000_TEST'),
        throwsA(
          isA<BusinessException>()
              .having((e) => e.code, 'code', 'coupon_min_amount_not_met'),
        ),
      );
    });

    test('a coupon at its global usage limit is rejected for a second booking', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(id: 'b1'), _pendingBooking(id: 'b2')],
      );
      await repo.applyCoupon(bookingId: 'b1', code: 'ONEUSE_TEST');

      await expectLater(
        repo.applyCoupon(bookingId: 'b2', code: 'ONEUSE_TEST'),
        throwsA(
          isA<BusinessException>()
              .having((e) => e.code, 'code', 'coupon_usage_limit_reached'),
        ),
      );
    });

    test('a coupon already used once by this user is rejected on another booking', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(id: 'b1'), _pendingBooking(id: 'b2')],
      );
      await repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10');

      await expectLater(
        repo.applyCoupon(bookingId: 'b2', code: 'WELCOME10'),
        throwsA(
          isA<BusinessException>()
              .having((e) => e.code, 'code', 'coupon_already_used_by_user'),
        ),
      );
    });

    test('applying to a non-pending booking is rejected (unauthorized manipulation guard)', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(status: BookingStatus.confirmed)],
      );
      await expectLater(
        repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10'),
        throwsA(
          isA<BusinessException>()
              .having((e) => e.code, 'code', 'invalid_booking_state'),
        ),
      );
    });

    test('applying to a booking that does not exist is rejected', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      await expectLater(
        repo.applyCoupon(bookingId: 'does-not-exist', code: 'WELCOME10'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('applyCoupon — retry / idempotency', () {
    test('re-applying the same code is a no-op, not a second redemption', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(id: 'b1'), _pendingBooking(id: 'b2')],
      );
      final first = await repo.applyCoupon(bookingId: 'b1', code: 'ONEUSE_TEST');
      final retry = await repo.applyCoupon(bookingId: 'b1', code: 'ONEUSE_TEST');

      expect(retry.discountAmount, first.discountAmount);
      expect(retry.totalAmount, first.totalAmount);
      // The single global redemption is still available only to b1 — a
      // second booking must still be rejected, proving the retry above
      // did not silently consume a second slot.
      await expectLater(
        repo.applyCoupon(bookingId: 'b2', code: 'ONEUSE_TEST'),
        throwsA(
          isA<BusinessException>()
              .having((e) => e.code, 'code', 'coupon_usage_limit_reached'),
        ),
      );
    });

    test('applying a different code replaces the prior one, not stacks it', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(amount: 100000, taxAmount: 0)],
      );
      final first = await repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10');
      expect(first.discountAmount, 5000); // capped

      final replaced = await repo.applyCoupon(bookingId: 'b1', code: 'FESTIVE500');
      expect(replaced.discountAmount, 500); // FESTIVE500 alone, not 5000+500
      expect(replaced.totalAmount, 99500);
    });
  });

  group('removeCoupon', () {
    test('clears a previously-applied discount', () async {
      final repo = MockBookingRepository(bookings: [_pendingBooking()]);
      await repo.applyCoupon(bookingId: 'b1', code: 'WELCOME10');

      final removed = await repo.removeCoupon('b1');
      expect(removed.discountAmount, 0);
      expect(removed.totalAmount, 41300);
    });

    test('freed usage slot can be redeemed by another booking', () async {
      final repo = MockBookingRepository(
        bookings: [_pendingBooking(id: 'b1'), _pendingBooking(id: 'b2')],
      );
      await repo.applyCoupon(bookingId: 'b1', code: 'ONEUSE_TEST');
      await repo.removeCoupon('b1');

      final onB2 = await repo.applyCoupon(bookingId: 'b2', code: 'ONEUSE_TEST');
      expect(onB2.discountAmount, 50);
    });
  });
}

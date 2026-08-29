import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/booking_repository.dart';

/// A promo code definition mirroring `public.coupons`, for the in-memory
/// repository below. Mirrors the same validation `apply_booking_coupon`
/// performs server-side, so widget tests exercise the same rules without a
/// live database.
class MockCoupon {
  const MockCoupon({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minBookingAmount = 0,
    this.maxUses,
    this.maxUsesPerUser = 1,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
  });

  final String code;
  final String discountType; // 'percentage' | 'fixed'
  final double discountValue;
  final double? maxDiscountAmount;
  final double minBookingAmount;
  final int? maxUses;
  final int? maxUsesPerUser;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
}

/// In-memory booking repository for tests and widget tests.
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({
    List<Booking>? bookings,
    List<SlotAvailability>? slots,
  }) : _bookings = bookings ?? [],
       _slots = slots ?? defaultSlots;

  final List<Booking> _bookings;
  final List<SlotAvailability> _slots;

  bool failAvailability = false;
  bool failAcquire = false;
  bool failCreate = false;
  bool failCancel = false;
  bool failApplyCoupon = false;
  Object? applyCouponError;

  /// Recorded params from the last [acquireHold] call.
  String? lastAcquiredVenueId;
  String? lastAcquiredSlotId;
  double? lastAcquiredAmount;
  Booking? createdBooking;

  /// code -> coupon, seeded with the same fixtures as the dev migration.
  final Map<String, MockCoupon> coupons = {
    for (final c in [
      MockCoupon(
        code: 'WELCOME10',
        discountType: 'percentage',
        discountValue: 10,
        maxDiscountAmount: 5000,
        minBookingAmount: 1000,
      ),
      MockCoupon(
        code: 'FESTIVE500',
        discountType: 'fixed',
        discountValue: 500,
        minBookingAmount: 10000,
      ),
      MockCoupon(
        code: 'EXPIRED_TEST',
        discountType: 'fixed',
        discountValue: 100,
        // A fixed point safely in the past (not DateTime.now(), which
        // would need this list to stop being const) — mirrors the
        // migration's EXPIRED_TEST fixture, which sets
        // ends_at = now() - interval '1 day'.
        endsAt: DateTime(2020, 1, 1),
      ),
      MockCoupon(
        code: 'INACTIVE_TEST',
        discountType: 'percentage',
        discountValue: 10,
        isActive: false,
      ),
      MockCoupon(
        code: 'MIN5000_TEST',
        discountType: 'fixed',
        discountValue: 200,
        minBookingAmount: 5000,
      ),
      MockCoupon(
        code: 'ONEUSE_TEST',
        discountType: 'fixed',
        discountValue: 50,
        maxUses: 1,
      ),
    ])
      c.code: c,
  };

  /// booking id -> currently-applied coupon code.
  final Map<String, String> _appliedCoupon = {};

  /// Global + per-user redemption counters, keyed by coupon code. This
  /// mock only ever represents a single signed-in user, so "global" and
  /// "per user" coincide here (the server tells them apart via user_id).
  final Map<String, int> _redemptions = {};

  static const List<SlotAvailability> defaultSlots = [
    SlotAvailability(
      slotId: 's1',
      label: 'Morning',
      startTime: '09:00:00',
      endTime: '13:00:00',
      priceAmount: 35000,
      isAvailable: true,
      reason: 'available',
    ),
    SlotAvailability(
      slotId: 's2',
      label: 'Afternoon',
      startTime: '14:00:00',
      endTime: '18:00:00',
      priceAmount: 35000,
      isAvailable: false,
      reason: 'booked',
    ),
    SlotAvailability(
      slotId: 's3',
      label: 'Evening',
      startTime: '19:00:00',
      endTime: '23:00:00',
      priceAmount: 45000,
      isAvailable: true,
      reason: 'available',
    ),
  ];

  static Booking sampleBooking({
    String id = 'b1',
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
      amount: 35000,
      taxAmount: 6300,
      totalAmount: 41300,
      venueName: 'Sunrise Function Hall',
      slotLabel: 'Morning',
    );
  }

  @override
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  }) async {
    if (failAvailability) throw Exception('network down');
    return _slots;
  }

  @override
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  }) async {
    if (failAcquire) {
      throw const BookingConflictException(
        'This slot was just taken. Please pick another.',
        code: 'slot_unavailable',
      );
    }
    lastAcquiredVenueId = venueId;
    lastAcquiredSlotId = slotId;
    lastAcquiredAmount = amount;
    return BookingHold(
      id: 'hold-1',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (failCreate) throw Exception('create failed');
    createdBooking = sampleBooking();
    return createdBooking!;
  }

  @override
  Future<Booking> bookingById(String bookingId) async {
    final match = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (match == null) {
      throw Exception('Booking not found: $bookingId');
    }
    return match;
  }

  @override
  Future<List<Booking>> myBookings() async {
    return List.of(_bookings);
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    if (failCancel) {
      throw const BookingConflictException(
        'This booking can no longer be cancelled.',
        code: 'cannot_cancel',
      );
    }
    _bookings.removeWhere((b) => b.id == bookingId);
  }

  @override
  Future<Booking> applyCoupon({
    required String bookingId,
    required String code,
  }) async {
    if (failApplyCoupon) {
      throw applyCouponError ??
          const BusinessException('apply failed', code: 'coupon_not_found');
    }
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index < 0) {
      throw const NotFoundException(
        'Booking not found.',
        code: 'booking_not_found',
      );
    }
    final booking = _bookings[index];
    if (booking.status != BookingStatus.pending) {
      throw const BusinessException(
        'This booking can no longer be changed.',
        code: 'invalid_booking_state',
      );
    }

    // Idempotent retry: same code already applied to this booking.
    final normalized = code.trim().toUpperCase();
    final already = _appliedCoupon[bookingId];
    if (already == normalized) {
      return booking;
    }

    final coupon = coupons[normalized];
    if (coupon == null) {
      throw const BusinessException(
        'That promo code was not found.',
        code: 'coupon_not_found',
      );
    }
    if (!coupon.isActive) {
      throw const BusinessException(
        'That promo code is no longer active.',
        code: 'coupon_inactive',
      );
    }
    final now = DateTime.now();
    if (coupon.startsAt != null && coupon.startsAt!.isAfter(now)) {
      throw const BusinessException(
        'That promo code is not active yet.',
        code: 'coupon_not_started',
      );
    }
    if (coupon.endsAt != null && !coupon.endsAt!.isAfter(now)) {
      throw const BusinessException(
        'That promo code has expired.',
        code: 'coupon_expired',
      );
    }

    final base = booking.amount + booking.taxAmount;
    if (coupon.minBookingAmount > base) {
      throw const BusinessException(
        'Your booking does not meet the minimum amount for this promo code.',
        code: 'coupon_min_amount_not_met',
      );
    }

    final used = _redemptions[normalized] ?? 0;
    if (coupon.maxUses != null && used >= coupon.maxUses!) {
      throw const BusinessException(
        'That promo code has reached its usage limit.',
        code: 'coupon_usage_limit_reached',
      );
    }
    if (coupon.maxUsesPerUser != null && used >= coupon.maxUsesPerUser!) {
      throw const BusinessException(
        "You've already used that promo code.",
        code: 'coupon_already_used_by_user',
      );
    }

    var discount = coupon.discountType == 'percentage'
        ? double.parse((base * coupon.discountValue / 100).toStringAsFixed(2))
        : coupon.discountValue;
    if (coupon.maxDiscountAmount != null) {
      discount = discount > coupon.maxDiscountAmount!
          ? coupon.maxDiscountAmount!
          : discount;
    }
    discount = discount > base ? base : (discount < 0 ? 0 : discount);

    // Replacing a different code releases the prior redemption slot.
    final prior = _appliedCoupon[bookingId];
    if (prior != null) {
      _redemptions[prior] = (_redemptions[prior] ?? 1) - 1;
    }
    _appliedCoupon[bookingId] = normalized;
    _redemptions[normalized] = (_redemptions[normalized] ?? 0) + 1;

    final updated = _copyWith(
      booking,
      discountAmount: discount,
      totalAmount: base - discount,
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<Booking> removeCoupon(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index < 0) {
      throw const NotFoundException(
        'Booking not found.',
        code: 'booking_not_found',
      );
    }
    final booking = _bookings[index];
    if (booking.status != BookingStatus.pending) {
      throw const BusinessException(
        'This booking can no longer be changed.',
        code: 'invalid_booking_state',
      );
    }
    final prior = _appliedCoupon.remove(bookingId);
    if (prior != null) {
      _redemptions[prior] = (_redemptions[prior] ?? 1) - 1;
    }
    final updated = _copyWith(
      booking,
      discountAmount: 0,
      totalAmount: booking.amount + booking.taxAmount,
    );
    _bookings[index] = updated;
    return updated;
  }

  Booking _copyWith(
    Booking b, {
    required double discountAmount,
    required double totalAmount,
  }) {
    return Booking(
      id: b.id,
      bookingRef: b.bookingRef,
      venueId: b.venueId,
      slotId: b.slotId,
      bookDate: b.bookDate,
      startTime: b.startTime,
      endTime: b.endTime,
      status: b.status,
      amount: b.amount,
      taxAmount: b.taxAmount,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      venueName: b.venueName,
      venueCity: b.venueCity,
      slotLabel: b.slotLabel,
      createdAt: b.createdAt,
      customerName: b.customerName,
      customerPhone: b.customerPhone,
      isOffline: b.isOffline,
      paymentMethod: b.paymentMethod,
      paymentRef: b.paymentRef,
      paidAt: b.paidAt,
      metadata: b.metadata,
    );
  }
}

import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/domain/booking_repository.dart';

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

  /// Recorded params from the last [acquireHold] call.
  String? lastAcquiredVenueId;
  String? lastAcquiredSlotId;
  double? lastAcquiredAmount;
  Booking? createdBooking;
  BookingStatus? createdStatus;

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
  }) async {
    if (failCreate) throw Exception('create failed');
    createdBooking = Booking(
      id: 'b1',
      bookingRef: 'BMS-1A2B3C',
      venueId: venueId,
      slotId: slotId,
      bookDate: bookDate,
      startTime: '09:00:00',
      endTime: '13:00:00',
      status:
          createdStatus ??
          (totalAmount == 0
              ? BookingStatus.confirmed
              : BookingStatus.paymentPending),
      amount: amount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      venueName: 'Sunrise Function Hall',
      slotLabel: 'Morning',
    );
    return createdBooking!;
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
}

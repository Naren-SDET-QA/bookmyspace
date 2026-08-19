import '../domain/booking.dart';

/// Contract for the booking flow.
///
/// The implementation talks to Supabase (PostgREST + Edge Functions). The
/// atomic slot lock lives server-side in `acquire_booking_hold`, which this
/// repository invokes through the `create-booking-hold` Edge Function so the
/// client never needs the service role.
abstract interface class BookingRepository {
  /// Lists every active slot of [venueId] with availability for [date].
  Future<List<SlotAvailability>> availableTimeSlots({
    required String venueId,
    required DateTime date,
  });

  /// Atomically reserves [slotId] on [date] for the current user.
  ///
  /// Throws a [BookingConflictException] when the slot is taken. The returned
  /// hold expires after `holdMinutes` unless the booking is confirmed.
  Future<BookingHold> acquireHold({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    int holdMinutes = 10,
  });

  /// Creates a pending booking tied to an acquired hold.
  ///
  /// [metadata] (e.g. guests, sharing option, check-out) is stored on the
  /// booking row's `metadata` jsonb column.
  Future<Booking> createBooking({
    required BookingHold hold,
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required double amount,
    required double taxAmount,
    required double totalAmount,
    Map<String, dynamic> metadata = const {},
  });

  /// A single booking by id (joined venue/slot/payment embeds).
  Future<Booking> bookingById(String bookingId);

  /// Bookings for the signed-in user, newest first.
  Future<List<Booking>> myBookings();

  /// Cancels a booking still in `pending` status.
  Future<void> cancelBooking(String bookingId);
}

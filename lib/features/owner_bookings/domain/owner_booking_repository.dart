import '../../booking/domain/booking.dart';

/// Status transitions an owner may apply to a booking of their venue.
enum OwnerBookingAction {
  confirm,
  complete,
  cancel,
  noShow;

  String get dbValue => switch (this) {
    OwnerBookingAction.confirm => 'confirm',
    OwnerBookingAction.complete => 'complete',
    OwnerBookingAction.cancel => 'cancel',
    OwnerBookingAction.noShow => 'no_show',
  };
}

/// Contract for owner-side booking management.
///
/// Reads run through RLS (owners can select bookings of their venues); all
/// writes run through the `owner-booking-manage` Edge Function with the
/// service role so status transitions are server-validated.
abstract interface class OwnerBookingRepository {
  /// Bookings across the signed-in owner's venues, newest first.
  Future<List<Booking>> myVenueBookings();

  /// Records a walk-in (offline) booking for one of the owner's venues.
  Future<Booking> createOfflineBooking({
    required String venueId,
    required String slotId,
    required DateTime bookDate,
    required String customerName,
    required String customerPhone,
    required double amount,
    required double taxAmount,
    required double totalAmount,
  });

  /// Applies a server-validated status transition to [bookingId].
  Future<Booking> updateStatus(String bookingId, OwnerBookingAction action);
}

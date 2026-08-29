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

/// An owner's decision on a booking awaiting their sign-off
/// (`BookingStatus.pendingOwnerApproval` — the customer has already paid).
enum OwnerBookingDecision {
  approve,
  reject;

  String get dbValue => switch (this) {
    OwnerBookingDecision.approve => 'approve',
    OwnerBookingDecision.reject => 'reject',
  };
}

/// Outcome of [OwnerBookingRepository.decideBooking].
///
/// `refundStatus` mirrors the server's `refund_status` field on a reject
/// decision (e.g. `requested`, `not_applicable`) and is null for an
/// approve decision.
class BookingDecisionOutcome {
  const BookingDecisionOutcome({required this.booking, this.refundStatus});

  final Booking booking;
  final String? refundStatus;
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

  /// Approves or rejects a booking awaiting owner sign-off
  /// (`status == pending_owner_approval`). Approve moves it to `confirmed`
  /// (the server also creates a `booking_orders` row); reject moves it to
  /// `rejected` and, for a captured online payment, triggers the existing
  /// server-side refund flow.
  Future<BookingDecisionOutcome> decideBooking(
    String bookingId,
    OwnerBookingDecision decision,
  );
}

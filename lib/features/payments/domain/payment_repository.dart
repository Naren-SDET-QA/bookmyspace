import '../../booking/domain/booking.dart';
import '../domain/payment.dart';

/// Contract for the payment flow.
///
/// The implementation talks to Supabase Edge Functions
/// (`create-payment-order`, `create-refund`) so Razorpay secrets never
/// reach the client. Booking confirmation itself is driven by the
/// `razorpay-webhook`, not by this repository.
abstract interface class PaymentRepository {
  /// Creates a Razorpay order for a `pending` booking (server validates the
  /// amount against the DB and returns the order id for checkout).
  Future<PaymentOrder> createOrder({required String bookingId});

  /// Commits a `pending` booking owned by the caller to "pay at venue"
  /// instead of an online Razorpay charge. No Razorpay order is ever
  /// created; the server records the payment method and advances the
  /// booking straight into the same owner-approval queue a captured
  /// online payment reaches. Returns the booking's new status
  /// (`pending_owner_approval` on success).
  Future<BookingStatus> selectPayAtVenue({required String bookingId});

  /// Refreshes the current status of [bookingId] (used to reflect the
  /// webhook-driven transition from `pending` to `confirmed`/`cancelled`).
  Future<BookingStatus> bookingStatus(String bookingId);

  /// Requests a refund for a captured payment of a confirmed booking.
  Future<Refund> requestRefund({
    required String bookingId,
    required double amount,
    String reason = '',
  });

  /// Payments belonging to the signed-in user, newest first.
  Future<List<Payment>> myPayments();
}

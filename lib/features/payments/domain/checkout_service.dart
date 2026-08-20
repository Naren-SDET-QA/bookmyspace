/// Outcome of a Razorpay checkout session.
enum CheckoutResult {
  /// The payment was authorised and captured by the provider.
  paid,

  /// The provider reported the payment failed.
  failed,

  /// The user closed the checkout without completing a payment.
  cancelled,

  /// Checkout did not reach a terminal provider callback before its timeout.
  timedOut,
}

/// Provider response captured from a successful checkout.
///
/// This is diagnostic/hand-off metadata only. Server-side webhook processing
/// remains authoritative for payment confirmation.
class CheckoutSuccessDetails {
  const CheckoutSuccessDetails({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;
}

/// Wraps the Razorpay Checkout SDK behind a small contract so the real
/// implementation can be swapped for a fake in tests and web builds.
abstract interface class CheckoutService {
  CheckoutSuccessDetails? get lastSuccessDetails;

  /// Opens the payment UI for [orderId] and waits for the terminal outcome.
  ///
  /// [keyId] is the Razorpay key that authorises the checkout and [amount]
  /// is the amount in the app currency (INR) for display.
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  });
}

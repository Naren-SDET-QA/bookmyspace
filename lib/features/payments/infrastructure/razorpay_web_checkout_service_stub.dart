import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Stub implementation used on non-web platforms. The real web implementation
/// lives in razorpay_web_checkout_service.dart and is conditionally imported
/// where needed.
class RazorpayWebCheckoutService implements CheckoutService {
  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  }) {
    throw const ConfigurationException(
      'Razorpay web checkout is not available on this platform.',
      code: 'razorpay_web_unavailable',
    );
  }
}

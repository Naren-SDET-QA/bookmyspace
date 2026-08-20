import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/payments/infrastructure/razorpay_checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing Razorpay key returns the existing friendly configuration error',
    () async {
      final service = RazorpayCheckoutService();

      expect(
        () => service.openCheckout(
          orderId: 'order_test',
          amount: 100,
          currency: 'INR',
          keyId: '',
        ),
        throwsA(
          isA<ConfigurationException>().having(
            (error) => error.code,
            'code',
            'razorpay_not_configured',
          ),
        ),
      );
    },
  );
}

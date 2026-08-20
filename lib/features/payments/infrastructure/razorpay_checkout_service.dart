import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Real Razorpay Checkout implementation (Android/iOS).
///
/// Requires a live test key: when [ConfigurationException] is thrown the
/// caller should surface a friendly message instead of crashing.
class RazorpayCheckoutService implements CheckoutService {
  @override
  CheckoutSuccessDetails? get lastSuccessDetails => null;

  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  }) async {
    if (keyId.trim().isEmpty || keyId.contains('PLACEHOLDER')) {
      throw const ConfigurationException(
        'Razorpay checkout is not configured. Add a test key to run payments.',
        code: 'razorpay_not_configured',
      );
    }

    final completer = Completer<CheckoutResult>();
    final razorpay = Razorpay();

    void successHandler(PaymentSuccessResponse response) {
      razorpay.clear();
      completer.complete(CheckoutResult.paid);
    }

    void errorHandler(PaymentFailureResponse response) {
      razorpay.clear();
      completer.complete(
        response.code == Razorpay.PAYMENT_CANCELLED
            ? CheckoutResult.cancelled
            : CheckoutResult.failed,
      );
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, successHandler);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, errorHandler);
    razorpay.open({
      'key': keyId,
      'order_id': orderId,
      'amount': (amount * 100).round(),
      'currency': currency,
      'name': 'BookMySpace',
      'prefill': const {'contact': '', 'email': ''},
      'theme': const {'color': '#6750A4'},
    });

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        razorpay.clear();
        return CheckoutResult.timedOut;
      },
    );
  }
}

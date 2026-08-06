// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist, undefined_operator, undefined_function, unused_element, inference_failure_on_collection_literal

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Web implementation of Razorpay Checkout using the official JS checkout.
/// Loads the checkout script if necessary and opens the UI. Completes with
/// the terminal CheckoutResult.
class RazorpayWebCheckoutService implements CheckoutService {
  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  }) async {
    if (keyId.contains('PLACEHOLDER')) {
      throw const ConfigurationException(
        'Razorpay checkout is not configured. Add a test key to run payments.',
        code: 'razorpay_not_configured',
      );
    }

    // Ensure the Razorpay script is loaded.
    if (!js_util.hasProperty(html.window, 'Razorpay')) {
      final script = html.ScriptElement()
        ..src = 'https://checkout.razorpay.com/v1/checkout.js'
        ..async = true;
      final loadCompleter = Completer<void>();
      script.onError.listen((_) {
        if (!loadCompleter.isCompleted) {
          loadCompleter.completeError(StateError('Could not load Razorpay checkout.'));
        }
      });
      script.onLoad.listen((_) {
        if (!loadCompleter.isCompleted) loadCompleter.complete();
      });
      html.document.head!.append(script);
      await loadCompleter.future;
      // Small delay to ensure the global is available.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!js_util.hasProperty(html.window, 'Razorpay')) {
        throw StateError('Razorpay checkout not available after loading script.');
      }
    }

    final completer = Completer<CheckoutResult>();

    // Success handler called by Razorpay JS when payment is completed.
    void successHandler(js.JsObject response) {
      if (!completer.isCompleted) completer.complete(CheckoutResult.paid);
    }

    // Failure handler for explicit payment.failed events.
    void failureHandler(js.JsObject response) {
      if (!completer.isCompleted) completer.complete(CheckoutResult.failed);
    }

    // Dismiss handler when user closes the modal.
    void dismissHandler() {
      if (!completer.isCompleted) completer.complete(CheckoutResult.cancelled);
    }

    // Build options map expected by Razorpay.
    final options = js_util.jsify({
      'key': keyId,
      'order_id': orderId,
      'amount': (amount * 100).round(),
      'currency': currency,
      'name': 'BookMySpace',
      'handler': js.allowInterop((response) {
        // On success, complete paid.
        if (!completer.isCompleted) completer.complete(CheckoutResult.paid);
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          if (!completer.isCompleted) completer.complete(CheckoutResult.cancelled);
        }),
      },
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#6750A4'},
    });

    // Construct Razorpay and open checkout.
    try {
      final razorpayConstructor = js_util.getProperty(html.window, 'Razorpay');
      final razorpay = js_util.callConstructor(razorpayConstructor, [options]);

      // Subscribe to payment.failed to catch explicit failures.
      try {
        js_util.callMethod(razorpay, 'on', [
          'payment.failed',
          js.allowInterop((err) {
            if (!completer.isCompleted) completer.complete(CheckoutResult.failed);
          })
        ]);
      } catch (_) {
        // Some razorpay versions may not support .on; ignore if it fails.
      }

      js_util.callMethod(razorpay, 'open', []);
    } catch (e) {
      if (!completer.isCompleted) completer.complete(CheckoutResult.failed);
    }

    // Safety timeout in case the checkout never completes.
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(CheckoutResult.failed);
        return CheckoutResult.failed;
      },
    );
  }
}

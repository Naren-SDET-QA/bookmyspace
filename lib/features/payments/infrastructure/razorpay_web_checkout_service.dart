import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exceptions.dart';
import '../domain/checkout_service.dart';

/// Razorpay Checkout.js adapter for Flutter Web.
///
/// Only the public checkout key and server-created order are sent to the
/// browser. Secrets and payment authorization remain in Edge Functions.
class RazorpayWebCheckoutService implements CheckoutService {
  static const _checkoutScript = 'https://checkout.razorpay.com/v1/checkout.js';
  static const _timeout = Duration(minutes: 5);
  static Future<void>? _scriptLoadFuture;

  JSObject? _activeCheckout;
  CheckoutSuccessDetails? _lastSuccessDetails;

  @override
  CheckoutSuccessDetails? get lastSuccessDetails => _lastSuccessDetails;

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

    await _loadScript();
    final razorpay = globalContext['Razorpay'] as JSFunction?;
    if (razorpay == null) {
      throw const ConfigurationException(
        'Razorpay checkout could not be loaded. Please try again.',
        code: 'razorpay_web_unavailable',
      );
    }

    final result = Completer<CheckoutResult>();
    var terminal = false;
    late JSObject instance;

    void complete(
      CheckoutResult value, {
      CheckoutSuccessDetails? successDetails,
    }) {
      if (terminal) return;
      terminal = true;
      _lastSuccessDetails = successDetails;
      if (identical(_activeCheckout, instance)) _activeCheckout = null;
      debugPrint('[razorpay-web] checkout_future_completed');
      result.complete(value);
    }

    final options = <String, Object?>{
      'key': keyId,
      'order_id': orderId,
      'amount': (amount * 100).round(),
      'currency': currency,
      'name': 'BookMySpace',
      'prefill': <String, String>{'contact': '', 'email': ''},
      'theme': <String, String>{'color': '#6750A4'},
      'handler': ((JSAny? response) {
        final details = _readSuccessDetails(response);
        if (details == null) {
          debugPrint('[razorpay-web] checkout_success_malformed');
          complete(CheckoutResult.failed);
          return;
        }
        debugPrint('[razorpay-web] checkout_success_callback');
        complete(CheckoutResult.paid, successDetails: details);
      }).toJS,
      'modal': <String, Object?>{
        'ondismiss': (() {
          debugPrint('[razorpay-web] checkout_dismissed');
          complete(CheckoutResult.cancelled);
        }).toJS,
      },
    };

    instance = razorpay.callAsConstructor<JSObject>(options.jsify());
    _activeCheckout = instance;

    void clearActiveCheckout() {
      if (identical(_activeCheckout, instance)) {
        _activeCheckout = null;
      }
    }

    try {
      instance.callMethod<JSAny?>(
        'on'.toJS,
        'payment.failed'.toJS,
        ((JSAny? _) {
          debugPrint('[razorpay-web] checkout_error_callback');
          clearActiveCheckout();
          complete(CheckoutResult.failed);
        }).toJS,
      );
      instance.callMethod<JSAny?>('open'.toJS);
    } catch (_) {
      debugPrint('[razorpay-web] checkout_open_failed');
      clearActiveCheckout();
      complete(CheckoutResult.failed);
    }

    return result.future.timeout(
      _timeout,
      onTimeout: () {
        debugPrint('[razorpay-web] checkout_timeout');
        if (identical(_activeCheckout, instance)) {
          try {
            instance.callMethod<JSAny?>('close'.toJS);
          } catch (_) {
            // The checkout may already have been dismissed by the provider.
          }
          _activeCheckout = null;
        }
        complete(CheckoutResult.timedOut);
        return CheckoutResult.timedOut;
      },
    );
  }

  CheckoutSuccessDetails? _readSuccessDetails(JSAny? response) {
    if (response is! JSObject) return null;
    final paymentId = _readString(response['razorpay_payment_id']);
    final orderId = _readString(response['razorpay_order_id']);
    final signature = _readString(response['razorpay_signature']);
    if (paymentId == null || orderId == null || signature == null) {
      return null;
    }
    return CheckoutSuccessDetails(
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  String? _readString(JSAny? value) {
    if (value is! JSString) return null;
    final text = value.toDart;
    return text.isEmpty ? null : text;
  }

  Future<void> _loadScript() async {
    if (globalContext['Razorpay'] != null) {
      return;
    }
    final inFlight = _scriptLoadFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final existing = html.document.querySelector(
      'script[src="$_checkoutScript"]',
    );
    final script =
        existing is html.ScriptElement ? existing : html.ScriptElement()
          ..src = _checkoutScript
          ..type = 'text/javascript';
    final loaded = Completer<void>();
    _scriptLoadFuture = loaded.future;

    void completeLoad() {
      if (!loaded.isCompleted) loaded.complete();
    }

    void failLoad() {
      if (!loaded.isCompleted) {
        loaded.completeError(
          const ConfigurationException(
            'Razorpay checkout could not be loaded. Please try again.',
            code: 'razorpay_web_load_failed',
          ),
        );
      }
    }

    script.onLoad.listen((_) => completeLoad());
    script.onError.listen((_) => failLoad());
    if (existing == null) {
      html.document.head?.append(script);
    }

    try {
      await loaded.future.timeout(_timeout);
      if (globalContext['Razorpay'] == null) {
        throw const ConfigurationException(
          'Razorpay checkout could not be loaded. Please try again.',
          code: 'razorpay_web_unavailable',
        );
      }
    } finally {
      _scriptLoadFuture = null;
    }
  }
}

import '../../../features/payments/domain/checkout_service.dart';
import '../app_plugin.dart';

/// Thin host around the existing Razorpay [CheckoutService] factory.
/// The SDK is still created inside [CheckoutService.openCheckout], not here.
class PaymentCheckoutPlugin implements AppPlugin {
  PaymentCheckoutPlugin(this._create);

  final CheckoutService Function() _create;
  CheckoutService? _checkout;
  bool _ready = false;

  CheckoutService get checkout => _checkout ??= _create();

  @override
  String get id => 'razorpay';

  @override
  bool get initialized => _ready;

  @override
  Future<void> ensureInitialized() async {
    checkout;
    _ready = true;
  }

  @override
  Future<void> dispose() async {
    _checkout = null;
    _ready = false;
  }
}

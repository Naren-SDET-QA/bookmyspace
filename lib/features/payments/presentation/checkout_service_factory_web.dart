import '../domain/checkout_service.dart';
import '../infrastructure/razorpay_web_checkout_service.dart';

CheckoutService createCheckoutService() => RazorpayWebCheckoutService();

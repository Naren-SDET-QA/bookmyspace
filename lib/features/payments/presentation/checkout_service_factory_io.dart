import '../domain/checkout_service.dart';
import '../infrastructure/razorpay_checkout_service.dart';

CheckoutService createCheckoutService() => RazorpayCheckoutService();

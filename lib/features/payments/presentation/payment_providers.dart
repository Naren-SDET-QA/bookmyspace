// ignore_for_file: directives_ordering
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../domain/checkout_service.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../infrastructure/razorpay_checkout_service.dart';
import '../infrastructure/supabase_payment_repository.dart';

// Conditionally import the web-only Razorpay implementation when dart:html is
// available; otherwise use the stub to avoid importing web libraries on mobile.
import '../infrastructure/razorpay_web_checkout_service_stub.dart'
    if (dart.library.html) '../infrastructure/razorpay_web_checkout_service.dart';

/// Payment repository instance.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabasePaymentRepository(client);
});

/// Razorpay checkout service. Uses a web JS-backed implementation on web
/// (real Razorpay checkout) and the native plugin on mobile.
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  if (kIsWeb) return RazorpayWebCheckoutService();
  return RazorpayCheckoutService();
});

/// The signed-in user's payments, newest first.
final myPaymentsProvider = FutureProvider<List<Payment>>((ref) {
  return ref.watch(paymentRepositoryProvider).myPayments();
});

final paymentReceiptProvider = FutureProvider.autoDispose
    .family<PaymentReceipt, String>((ref, bookingId) {
      return ref.watch(paymentRepositoryProvider).receipt(bookingId);
    });

/// Live status of a single booking, refreshed by polling after checkout.
final bookingStatusProvider = FutureProvider.autoDispose
    .family<BookingStatus, String>((ref, bookingId) {
      return ref.watch(paymentRepositoryProvider).bookingStatus(bookingId);
    });

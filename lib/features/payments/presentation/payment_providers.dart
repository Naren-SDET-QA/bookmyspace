import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../domain/checkout_service.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../infrastructure/supabase_payment_repository.dart';
import 'checkout_service_factory.dart';

/// Payment repository instance.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabasePaymentRepository(client);
});

/// Razorpay checkout service. Overridden with a fake in tests/web.
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  return createCheckoutService();
});

/// The signed-in user's payments, newest first.
final myPaymentsProvider = FutureProvider<List<Payment>>((ref) {
  return ref.watch(paymentRepositoryProvider).myPayments();
});

/// Live status of a single booking, refreshed by polling after checkout.
final bookingStatusProvider = FutureProvider.autoDispose
    .family<BookingStatus, String>((ref, bookingId) {
      return ref.watch(paymentRepositoryProvider).bookingStatus(bookingId);
    });

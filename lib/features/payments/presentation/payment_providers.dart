import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modular/feature_providers.dart';
import '../../../core/modular/plugin_kind.dart';
import '../../../core/modular/plugins/payment_checkout_plugin.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../booking/domain/booking.dart';
import '../domain/checkout_service.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../infrastructure/supabase_payment_repository.dart';

/// Payment repository instance.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabasePaymentRepository(client);
});

/// Razorpay checkout service. Resolved from [ProviderRegistry] so a disabled
/// payments feature never constructs checkout. Tests still override this.
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  final features = ref.watch(featureRegistryProvider);
  if (!isCheckoutExposed(features)) {
    throw StateError('payments plugin is not available');
  }
  final plugin = ref
      .watch(providerRegistryProvider)
      .tryResolve(PluginKind.payment);
  if (plugin is PaymentCheckoutPlugin) return plugin.checkout;
  throw StateError('payments plugin is not available');
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

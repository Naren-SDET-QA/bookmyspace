import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/presentation/booking_providers.dart';
import '../../payments/presentation/payment_providers.dart';
import '../domain/customer_analytics.dart';

final customerAnalyticsProvider = FutureProvider.autoDispose
    .family<CustomerAnalytics, ({DateTime? start, DateTime? end})>((
      ref,
      range,
    ) async {
      final payments = await ref.watch(myPaymentsProvider.future);
      final bookings = await ref.watch(myBookingsProvider.future);
      return CustomerAnalytics.fromData(
        payments: payments,
        bookings: bookings,
        start: range.start,
        end: range.end,
      );
    });

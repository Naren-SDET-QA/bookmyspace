import 'payment.dart';

enum PaymentHistoryFilter { all, pending, captured, failed, refunded }

/// Client-side view filter over server payment rows.
/// Does not change payment status or invent captures.
class PaymentHistoryQuery {
  const PaymentHistoryQuery({
    this.filter = PaymentHistoryFilter.all,
    this.query = '',
  });

  final PaymentHistoryFilter filter;
  final String query;

  List<Payment> apply(List<Payment> payments) {
    final needle = query.trim().toLowerCase();
    return payments.where((payment) {
      if (!_matchesFilter(payment)) return false;
      if (needle.isEmpty) return true;
      return [
        payment.id,
        payment.bookingId,
        payment.providerOrderId,
        payment.providerPaymentId,
        payment.status.dbValue,
        payment.method,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList();
  }

  bool _matchesFilter(Payment payment) {
    return switch (filter) {
      PaymentHistoryFilter.all => true,
      PaymentHistoryFilter.pending =>
        payment.status == PaymentStatus.pending ||
            payment.status == PaymentStatus.authorized,
      PaymentHistoryFilter.captured =>
        payment.status == PaymentStatus.captured,
      PaymentHistoryFilter.failed => payment.status == PaymentStatus.failed,
      PaymentHistoryFilter.refunded =>
        payment.status == PaymentStatus.refunded ||
            payment.status == PaymentStatus.partiallyRefunded,
    };
  }
}

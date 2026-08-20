import '../../booking/domain/booking.dart';
import '../../payments/domain/payment.dart';

class CustomerAnalytics {
  const CustomerAnalytics({
    required this.spent,
    required this.bookings,
    required this.completed,
    required this.cancelled,
    required this.refunded,
    required this.monthly,
    required this.recent,
  });
  final double spent;
  final int bookings;
  final int completed;
  final int cancelled;
  final int refunded;
  final Map<String, double> monthly;
  final List<Payment> recent;

  factory CustomerAnalytics.fromData({
    required List<Payment> payments,
    required List<Booking> bookings,
    DateTime? start,
    DateTime? end,
  }) {
    final selected = bookings.where((b) {
      final d = b.createdAt ?? b.bookDate;
      return (start == null || !d.isBefore(start)) &&
          (end == null || d.isBefore(end.add(const Duration(days: 1))));
    }).toList();
    final ids = selected.map((b) => b.id).toSet();
    final relevant = payments.where((p) => ids.contains(p.bookingId)).toList();
    double spent = 0;
    final months = <String, double>{};
    for (final payment in relevant) {
      if (payment.status != PaymentStatus.captured &&
          payment.status != PaymentStatus.refunded &&
          payment.status != PaymentStatus.partiallyRefunded)
        continue;
      final amount = payment.status == PaymentStatus.refunded
          ? -payment.amount
          : payment.amount;
      spent += amount;
      final booking = selected.firstWhere((b) => b.id == payment.bookingId);
      final d = booking.createdAt ?? booking.bookDate;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      months[key] = (months[key] ?? 0) + amount;
    }
    return CustomerAnalytics(
      spent: spent,
      bookings: selected.length,
      completed: selected
          .where((b) => b.status == BookingStatus.completed)
          .length,
      cancelled: selected
          .where((b) => b.status == BookingStatus.cancelled)
          .length,
      refunded: selected
          .where((b) => b.status == BookingStatus.refunded)
          .length,
      monthly: months,
      recent: relevant.take(10).toList(),
    );
  }
}

import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/domain/payment_history_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Payment payment({
    required String id,
    required PaymentStatus status,
    String bookingId = 'b1',
    String providerPaymentId = '',
  }) {
    return Payment(
      id: id,
      bookingId: bookingId,
      amount: 100,
      currency: 'INR',
      status: status,
      providerPaymentId: providerPaymentId,
    );
  }

  final rows = [
    payment(id: 'p1', status: PaymentStatus.pending, bookingId: 'hold-1'),
    payment(id: 'p2', status: PaymentStatus.captured, providerPaymentId: 'pay_abc'),
    payment(id: 'p3', status: PaymentStatus.failed),
    payment(id: 'p4', status: PaymentStatus.refunded),
    payment(id: 'p5', status: PaymentStatus.authorized),
  ];

  test('all filter keeps every server row', () {
    expect(const PaymentHistoryQuery().apply(rows), hasLength(5));
  });

  test('pending includes authorized and pending only', () {
    final visible = const PaymentHistoryQuery(
      filter: PaymentHistoryFilter.pending,
    ).apply(rows);
    expect(visible.map((p) => p.id), ['p1', 'p5']);
  });

  test('search matches razorpay id without changing status', () {
    final visible = const PaymentHistoryQuery(query: 'pay_abc').apply(rows);
    expect(visible, hasLength(1));
    expect(visible.single.status, PaymentStatus.captured);
  });

  test('failed filter never promotes a capture', () {
    final visible = const PaymentHistoryQuery(
      filter: PaymentHistoryFilter.failed,
    ).apply(rows);
    expect(visible.single.id, 'p3');
  });
}

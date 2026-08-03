import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentStatus', () {
    test('round-trips db values', () {
      for (final status in PaymentStatus.values) {
        expect(PaymentStatus.fromDb(status.dbValue), status);
      }
    });

    test('unknown status falls back to pending', () {
      expect(PaymentStatus.fromDb('weird'), PaymentStatus.pending);
    });
  });

  group('PaymentOrder', () {
    test('parses the create-payment-order response', () {
      final order = PaymentOrder.fromResponse({
        'order_id': 'order_1',
        'amount': 41300,
        'currency': 'INR',
      });
      expect(order.orderId, 'order_1');
      expect(order.amount, 41300);
      expect(order.currency, 'INR');
    });
  });

  group('Payment', () {
    test('parses a captured payment', () {
      final payment = Payment.fromJson({
        'id': 'p1',
        'booking_id': 'b1',
        'provider_order_id': 'order_1',
        'provider_payment_id': 'pay_1',
        'amount': 41300,
        'currency': 'INR',
        'status': 'captured',
        'method': 'upi',
      });
      expect(payment.status, PaymentStatus.captured);
      expect(payment.isRefundable, isTrue);
    });

    test('a refunded payment is not refundable', () {
      final payment = Payment.fromJson({'status': 'refunded'});
      expect(payment.isRefundable, isFalse);
    });
  });

  group('Refund', () {
    test('parses a refund row', () {
      final refund = Refund.fromJson({
        'id': 'r1',
        'payment_id': 'p1',
        'booking_id': 'b1',
        'amount': 41300,
        'status': 'processed',
        'reason': 'cancelled',
        'provider_refund_id': 'rfnd_1',
        'processed_at': '2026-08-01T10:00:00Z',
      });
      expect(refund.id, 'r1');
      expect(refund.amount, 41300);
      expect(refund.status, 'processed');
      expect(refund.processedAt, isNotNull);
    });

    test('fromResponse maps malformed data to a typed error', () {
      expect(() => Refund.fromResponse('not a map'), throwsA(isA<Exception>()));
    });
  });
}

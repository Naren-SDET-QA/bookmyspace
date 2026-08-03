import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/payments/domain/checkout_service.dart';
import 'package:bookmyspace/features/payments/domain/payment.dart';
import 'package:bookmyspace/features/payments/domain/payment_repository.dart';

/// In-memory payment repository for tests and widget tests.
class MockPaymentRepository implements PaymentRepository {
  MockPaymentRepository();

  bool failCreateOrder = false;
  bool failRefund = false;
  bool failStatus = false;

  BookingStatus statusResult = BookingStatus.confirmed;
  int statusCalls = 0;

  Refund? createdRefund;
  String? lastOrderBookingId;
  String? lastRefundBookingId;
  double? lastRefundAmount;

  static const List<Payment> defaultPayments = [
    Payment(
      id: 'p1',
      bookingId: 'b1',
      providerOrderId: 'order_1',
      providerPaymentId: 'pay_1',
      amount: 41300,
      currency: 'INR',
      status: PaymentStatus.captured,
    ),
  ];

  static PaymentOrder sampleOrder({String orderId = 'order_1'}) =>
      PaymentOrder(orderId: orderId, amount: 41300, currency: 'INR');

  static Refund sampleRefund() => const Refund(
    id: 'r1',
    paymentId: 'p1',
    bookingId: 'b1',
    amount: 41300,
    status: 'processed',
    reason: '',
    providerRefundId: 'rfnd_1',
  );

  @override
  Future<PaymentOrder> createOrder({required String bookingId}) async {
    if (failCreateOrder) throw Exception('order creation failed');
    lastOrderBookingId = bookingId;
    return sampleOrder();
  }

  @override
  Future<BookingStatus> bookingStatus(String bookingId) async {
    statusCalls++;
    if (failStatus) throw Exception('status failed');
    return statusResult;
  }

  @override
  Future<Refund> requestRefund({
    required String bookingId,
    required double amount,
    String reason = '',
  }) async {
    if (failRefund) throw Exception('refund failed');
    lastRefundBookingId = bookingId;
    lastRefundAmount = amount;
    createdRefund = sampleRefund();
    return createdRefund!;
  }

  @override
  Future<List<Payment>> myPayments() async {
    return List.of(defaultPayments);
  }
}

/// A checkout service that records the opened order and returns a fixed
/// outcome, so payment widget tests never touch the native SDK.
class FakeCheckoutService implements CheckoutService {
  FakeCheckoutService([this.result = CheckoutResult.paid]);

  CheckoutResult result;
  String? lastOrderId;
  double? lastAmount;
  String? lastCurrency;
  String? lastKeyId;

  @override
  Future<CheckoutResult> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String keyId,
  }) async {
    lastOrderId = orderId;
    lastAmount = amount;
    lastCurrency = currency;
    lastKeyId = keyId;
    return result;
  }
}

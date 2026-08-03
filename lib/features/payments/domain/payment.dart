import '../../../core/errors/app_exceptions.dart' as app_errors;

/// Lifecycle status of a payment (`payment_status` enum).
enum PaymentStatus {
  pending,
  authorized,
  captured,
  failed,
  refunded,
  partiallyRefunded;

  static PaymentStatus fromDb(String value) => switch (value) {
    'pending' => PaymentStatus.pending,
    'authorized' => PaymentStatus.authorized,
    'captured' => PaymentStatus.captured,
    'failed' => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    'partially_refunded' => PaymentStatus.partiallyRefunded,
    _ => PaymentStatus.pending,
  };

  String get dbValue => switch (this) {
    PaymentStatus.pending => 'pending',
    PaymentStatus.authorized => 'authorized',
    PaymentStatus.captured => 'captured',
    PaymentStatus.failed => 'failed',
    PaymentStatus.refunded => 'refunded',
    PaymentStatus.partiallyRefunded => 'partially_refunded',
  };
}

/// A Razorpay order created server-side, ready for checkout.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
  });

  final String orderId;
  final double amount;
  final String currency;

  factory PaymentOrder.fromResponse(Map<String, dynamic> json) => PaymentOrder(
    orderId: json['order_id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'INR',
  );
}

/// A payment row for a booking (`payments`).
class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.currency,
    required this.status,
    this.providerOrderId = '',
    this.providerPaymentId = '',
    this.method = '',
  });

  final String id;
  final String bookingId;
  final String providerOrderId;
  final String providerPaymentId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String method;

  bool get isRefundable =>
      status == PaymentStatus.captured ||
      status == PaymentStatus.partiallyRefunded;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String? ?? '',
    bookingId: json['booking_id'] as String? ?? '',
    providerOrderId: json['provider_order_id'] as String? ?? '',
    providerPaymentId: json['provider_payment_id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    status: PaymentStatus.fromDb(json['status'] as String? ?? 'pending'),
    method: json['method'] as String? ?? '',
  );
}

/// A refund for a captured payment (`refunds`).
class Refund {
  const Refund({
    required this.id,
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.status,
    this.reason = '',
    this.providerRefundId = '',
    this.processedAt,
  });

  final String id;
  final String paymentId;
  final String bookingId;
  final double amount;
  final String status;
  final String reason;
  final String providerRefundId;
  final DateTime? processedAt;

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
    id: json['id'] as String? ?? '',
    paymentId: json['payment_id'] as String? ?? '',
    bookingId: json['booking_id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'requested',
    reason: json['reason'] as String? ?? '',
    providerRefundId: json['provider_refund_id'] as String? ?? '',
    processedAt: DateTime.tryParse(json['processed_at'] as String? ?? ''),
  );

  /// Parses the response of the `create-refund` Edge Function.
  factory Refund.fromResponse(Object? json) {
    if (json is Map<String, dynamic>) {
      return Refund.fromJson(json);
    }
    throw const app_errors.SerializationException(
      'Could not read the refund response.',
    );
  }
}

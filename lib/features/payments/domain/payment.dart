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
    this.keyId,
  });

  final String orderId;
  final double amount;
  final String currency;
  /// Public Razorpay key id returned by `create-payment-order` when configured.
  final String? keyId;

  factory PaymentOrder.fromResponse(Map<String, dynamic> json) => PaymentOrder(
    orderId: json['order_id'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    keyId: json['key_id'] as String?,
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

class PaymentReceipt {
  const PaymentReceipt({
    required this.bookingId,
    required this.bookingRef,
    required this.hallName,
    required this.customerName,
    required this.bookDate,
    required this.startTime,
    required this.endTime,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.bookingStatus,
    required this.paymentStatus,
    this.receiptNumber = '',
    this.customerPhone = '',
    this.paymentRef = '',
  });

  final String bookingId;
  final String bookingRef;
  final String receiptNumber;
  final String hallName;
  final String customerName;
  final String customerPhone;
  final DateTime bookDate;
  final String startTime;
  final String endTime;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final String bookingStatus;
  final String paymentStatus;
  final String paymentRef;

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) => PaymentReceipt(
    bookingId: json['booking_id'] as String? ?? '',
    bookingRef: json['booking_ref'] as String? ?? '',
    receiptNumber: json['receipt_number'] as String? ?? '',
    hallName: json['hall_name'] as String? ?? '',
    customerName: json['customer_name'] as String? ?? '',
    customerPhone: json['customer_phone'] as String? ?? '',
    bookDate:
        DateTime.tryParse(json['book_date']?.toString() ?? '') ??
        DateTime(1970),
    startTime: json['start_time']?.toString() ?? '',
    endTime: json['end_time']?.toString() ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
    bookingStatus: json['booking_status'] as String? ?? '',
    paymentStatus: json['payment_status'] as String? ?? '',
    paymentRef: json['payment_ref'] as String? ?? '',
  );
}

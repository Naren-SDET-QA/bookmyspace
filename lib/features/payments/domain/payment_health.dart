class PaymentHealthSummary {
  const PaymentHealthSummary({
    required this.paymentsByStatus,
    required this.refundsByStatus,
    required this.activeHolds,
    this.generatedAt,
  });

  final Map<String, int> paymentsByStatus;
  final Map<String, int> refundsByStatus;
  final int activeHolds;
  final DateTime? generatedAt;

  int count(String status) => paymentsByStatus[status] ?? 0;

  int get pending => count('pending') + count('authorized');
  int get captured => count('captured');
  int get failed => count('failed');
  int get refunded =>
      count('refunded') + count('partially_refunded');

  factory PaymentHealthSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts(dynamic raw) {
      if (raw is! Map) return const {};
      return raw.map(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
    }

    return PaymentHealthSummary(
      paymentsByStatus: counts(json['payments']),
      refundsByStatus: counts(json['refunds']),
      activeHolds: (json['active_holds'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }
}

abstract interface class PaymentHealthRepository {
  Future<PaymentHealthSummary> summary();

  /// Marks stale *pending* payments failed. Server-authoritative.
  /// Does not invent captured payments or bookings.
  Future<int> reconcileStale({int staleAfterMinutes = 30});
}

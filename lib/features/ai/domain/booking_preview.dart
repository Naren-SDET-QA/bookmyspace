class BookingPreview {
  const BookingPreview({
    required this.venueId,
    required this.venueName,
    required this.slotId,
    required this.date,
    required this.slotLabel,
    required this.baseAmount,
    required this.taxAmount,
    required this.feeAmount,
    required this.discountAmount,
    required this.quantity,
    required this.totalAmount,
    required this.currency,
    required this.requiresConfirmation,
  });

  final String venueId;
  final String venueName;
  final String slotId;
  final String date;
  final String slotLabel;
  final double baseAmount;
  final double taxAmount;
  final double feeAmount;
  final double discountAmount;
  final int quantity;
  final double totalAmount;
  final String currency;
  final bool requiresConfirmation;

  factory BookingPreview.fromActionResponse(Map<String, dynamic> response) {
    final raw = response['preview'];
    if (raw is! Map) throw const FormatException('Invalid booking preview');
    final preview = Map<String, dynamic>.from(raw);
    final venue = _map(preview['venue']);
    final slot = _map(preview['slot']);
    final pricing = _map(preview['pricing']);
    final venueId = venue['id']?.toString();
    final slotId = slot['id']?.toString();
    if (venueId == null || slotId == null || pricing['total_amount'] == null) {
      throw const FormatException('Incomplete booking preview');
    }
    return BookingPreview(
      venueId: venueId,
      venueName: venue['name']?.toString() ?? 'Selected space',
      slotId: slotId,
      date: slot['date']?.toString() ?? '',
      slotLabel: slot['label']?.toString() ?? '',
      baseAmount: _number(pricing['amount']),
      taxAmount: _number(pricing['tax_amount']),
      feeAmount: _number(pricing['fee_amount'] ?? pricing['fees']),
      discountAmount: _number(
        pricing['discount_amount'] ?? pricing['discount'],
      ),
      quantity: (preview['quantity'] as num?)?.toInt() ?? 1,
      totalAmount: _number(pricing['total_amount']),
      currency: pricing['currency']?.toString() ?? 'INR',
      requiresConfirmation: preview['requires_confirmation'] == true,
    );
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static double _number(Object? value) => value is num ? value.toDouble() : 0;
}

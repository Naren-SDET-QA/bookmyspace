enum UniversalIntentKind {
  discoverCategory,
  search,
  location,
  availability,
  resourceDetails,
  price,
  createHold,
  confirmBooking,
  bookingStatus,
  cancelBooking,
  refundStatus,
  getInvoice,
  getQr,
  getHelp,
  getOffer,
}

class UniversalIntent {
  const UniversalIntent({
    required this.kind,
    this.category,
    this.location,
    this.values = const {},
    this.untrustedFields = const [],
  });

  final UniversalIntentKind kind;
  final String? category;
  final String? location;
  final Map<String, dynamic> values;
  final List<String> untrustedFields;

  bool get requiresConfirmation => {
        UniversalIntentKind.createHold,
        UniversalIntentKind.confirmBooking,
        UniversalIntentKind.cancelBooking,
      }.contains(kind);

  static UniversalIntent fromMap(Map<String, dynamic> source) {
    final raw = source['intent']?.toString().toUpperCase();
    final kind = _parseKind(raw);
    final protectedFields = [
      'user_id',
      'organization_id',
      'tenant_id',
      'category_id',
      'price',
      'base_price',
      'tax',
      'fees',
      'discount',
      'refund_amount',
      'total',
      'currency',
      'permissions',
    ];
    final untrusted = source.keys.where(protectedFields.contains).toList(growable: false);
    final values = Map<String, dynamic>.from(source)
      ..removeWhere((key, _) => {'intent', 'category', 'location', ...protectedFields}.contains(key));
    return UniversalIntent(
      kind: kind,
      category: source['category']?.toString(),
      location: source['location']?.toString(),
      values: values,
      untrustedFields: untrusted,
    );
  }

  ValidationResult validate({required List<String> requiredFields, bool confirmed = false}) {
    if (requiresConfirmation && !confirmed) {
      return const ValidationResult(missingFields: [], question: 'Please confirm before continuing.');
    }
    final missing = requiredFields.where((field) {
      final value = values[field];
      return value == null || (value is String && value.trim().isEmpty);
    }).toList(growable: false);
    if (missing.isEmpty) return const ValidationResult();
    return ValidationResult(missingFields: missing, question: 'Please provide ${missing.first.replaceAll('_', ' ')}.');
  }

  static UniversalIntentKind _parseKind(String? value) {
    const names = {
      'DISCOVER_CATEGORY': UniversalIntentKind.discoverCategory,
      'SEARCH': UniversalIntentKind.search,
      'LOCATION': UniversalIntentKind.location,
      'AVAILABILITY': UniversalIntentKind.availability,
      'RESOURCE_DETAILS': UniversalIntentKind.resourceDetails,
      'PRICE': UniversalIntentKind.price,
      'CREATE_HOLD': UniversalIntentKind.createHold,
      'CONFIRM_BOOKING': UniversalIntentKind.confirmBooking,
      'BOOKING_STATUS': UniversalIntentKind.bookingStatus,
      'CANCEL_BOOKING': UniversalIntentKind.cancelBooking,
      'REFUND_STATUS': UniversalIntentKind.refundStatus,
      'GET_INVOICE': UniversalIntentKind.getInvoice,
      'GET_QR': UniversalIntentKind.getQr,
      'GET_HELP': UniversalIntentKind.getHelp,
      'GET_OFFER': UniversalIntentKind.getOffer,
    };
    final parsed = names[value];
    if (parsed == null) throw FormatException('Unsupported intent');
    return parsed;
  }
}

class ValidationResult {
  const ValidationResult({this.missingFields = const [], this.question});
  final List<String> missingFields;
  final String? question;
  bool get isValid => missingFields.isEmpty && question == null;
}

enum PricingModel { oneTime, payPerView, subscription, perLead }

class ContactPaymentOrder {
  const ContactPaymentOrder({
    required this.orderId,
    required this.amountMinor,
    required this.currency,
  });
  final String orderId;
  final int amountMinor;
  final String currency;

  factory ContactPaymentOrder.fromJson(Map<String, dynamic> json) =>
      ContactPaymentOrder(
        orderId: json['order_id'] as String? ?? '',
        amountMinor: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
      );
}

class PricingFeature {
  const PricingFeature({
    required this.featureKey,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.pricingModel,
    required this.version,
    this.description = '',
    this.taxBps = 0,
    this.durationDays,
    this.isActive = true,
  });

  final String featureKey;
  final String name;
  final String description;
  final int amountMinor;
  final String currency;
  final int taxBps;
  final PricingModel pricingModel;
  final int? durationDays;
  final bool isActive;
  final int version;

  factory PricingFeature.fromJson(Map<String, dynamic> json) => PricingFeature(
    featureKey: json['feature_key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    taxBps: (json['tax_bps'] as num?)?.toInt() ?? 0,
    pricingModel: PricingModel.values.firstWhere(
      (model) => model.name == _modelName(json['pricing_model'] as String?),
      orElse: () => PricingModel.oneTime,
    ),
    durationDays: (json['duration_days'] as num?)?.toInt(),
    isActive: json['is_active'] as bool? ?? false,
    version: (json['version'] as num?)?.toInt() ?? 1,
  );

  static String _modelName(String? value) => switch (value) {
    'pay_per_view' => 'payPerView',
    'per_lead' => 'perLead',
    'subscription' => 'subscription',
    _ => 'oneTime',
  };
}

class BusinessPlan {
  const BusinessPlan({
    required this.id,
    required this.planKey,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.durationDays,
    required this.imageLimit,
    required this.leadLimit,
    required this.isActive,
    this.entitlements = const {},
  });
  final String id;
  final String planKey;
  final String name;
  final int amountMinor;
  final String currency;
  final int durationDays;
  final int imageLimit;
  final int leadLimit;
  final bool isActive;
  final Map<String, dynamic> entitlements;
  factory BusinessPlan.fromJson(Map<String, dynamic> json) => BusinessPlan(
    id: json['id'] as String? ?? '',
    planKey: json['plan_key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    amountMinor: (json['amount_minor'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'INR',
    durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
    imageLimit: (json['image_limit'] as num?)?.toInt() ?? 0,
    leadLimit: (json['lead_limit'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] as bool? ?? false,
    entitlements: Map<String, dynamic>.from(
      json['entitlements'] as Map? ?? const {},
    ),
  );
}

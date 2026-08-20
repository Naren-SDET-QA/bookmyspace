import 'dart:core';

/// Represents an institute listing (advertisement) created by an owner.
class InstituteListing {
  const InstituteListing({
    required this.id,
    required this.instituteId,
    required this.planId,
    required this.paymentId,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String instituteId;
  final String planId;
  final String? paymentId; // nullable until payment is made
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InstituteListing.fromJson(Map<String, dynamic> json) {
    return InstituteListing(
      id: json['id'] as String,
      instituteId: json['institute_id'] as String,
      planId: json['plan_id'] as String,
      paymentId: json['payment_id'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institute_id': instituteId,
      'plan_id': planId,
      'payment_id': paymentId,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns true if the listing is currently active (within validity period and active flag).
  bool get isValid => isActive && endsAt.isAfter(DateTime.now());

  /// Returns true if the listing has expired.
  bool get isExpired => endsAt.isBefore(DateTime.now());
}

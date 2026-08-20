import 'dart:core';

/// Represents an institute listing plan (subscription plan for advertising).
class InstituteListingPlan {
  const InstituteListingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationInDays,
    required this.features,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final int durationInDays;
  final List<String> features;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory InstituteListingPlan.fromJson(Map<String, dynamic> json) {
    return InstituteListingPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String ?? '',
      price: (json['price'] as num).toDouble(),
      durationInDays: json['duration_in_days'] as int,
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_in_days': durationInDays,
      'features': features,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

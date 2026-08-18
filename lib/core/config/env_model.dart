import 'package:flutter/foundation.dart';

/// Defines the configuration data model for environment settings.
@immutable
class EnvModel {
  const EnvModel({
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.razorpayKeyId,
    required this.apiBaseUrl,
  });

  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String razorpayKeyId;
  final String apiBaseUrl;

  bool get isDevelopment => name == 'development' || name == 'local';
  bool get isStaging => name == 'staging' || name == 'testing';
  bool get isProduction => name == 'production';
  bool get isRazorpayTestMode => razorpayKeyId.startsWith('rzp_test_');

  Map<String, dynamic> toSummaryMap() => {
        'name': name,
        'supabaseUrl': supabaseUrl,
        'isRazorpayTestMode': isRazorpayTestMode,
        'isDevelopment': isDevelopment,
        'isStaging': isStaging,
        'isProduction': isProduction,
      };

  @override
  String toString() => 'EnvModel(name: $name, supabaseUrl: $supabaseUrl, isRazorpayTestMode: $isRazorpayTestMode)';
}

import 'package:flutter/foundation.dart';

/// Supported runtime environments.
///
/// Secrets must never be committed. Real values come from
/// `--dart-define` flags at build time (see the `--dart-define` examples in
/// the README). The defaults below are safe placeholders only.
enum AppEnvironment {
  local(
    name: 'local',
    supabaseUrl: 'http://127.0.0.1:54321',
    supabaseAnonKey: 'LOCAL_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'http://127.0.0.1:8080',
  ),
  development(
    name: 'development',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'DEV_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  testing(
    name: 'testing',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'TEST_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  staging(
    name: 'staging',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'STAGING_ANON_KEY',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  production(
    name: 'production',
    supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
    supabaseAnonKey: 'PROD_ANON_KEY',
    razorpayKeyId: 'rzp_live_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  );

  const AppEnvironment({
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

  static const String _envDefine = String.fromEnvironment('APP_ENV');

  /// Resolves the active environment from `--dart-define=APP_ENV=...`.
  static AppEnvironment get current {
    if (_envDefine.isNotEmpty) {
      return AppEnvironment.values.firstWhere(
        (e) => e.name == _envDefine,
        orElse: () => AppEnvironment.development,
      );
    }
    if (kReleaseMode) return AppEnvironment.production;
    if (kProfileMode) return AppEnvironment.staging;
    return AppEnvironment.development;
  }
}

/// App-wide configuration resolved once at startup.
class AppConfig {
  const AppConfig._();

  static AppEnvironment get environment => AppEnvironment.current;
  static String get supabaseUrl => environment.supabaseUrl;
  static String get supabaseAnonKey => environment.supabaseAnonKey;
  static String get razorpayKeyId => environment.razorpayKeyId;
  static String get apiBaseUrl => environment.apiBaseUrl;
  static String get appName => 'BookMySpace';

  /// Booking hold duration before automatic expiry (server enforced too).
  static const Duration bookingHoldDuration = Duration(minutes: 10);
  static const int requestTimeoutSeconds = 20;
  static const int maxRetries = 3;
}

import 'package:flutter/foundation.dart';
import 'env_model.dart';

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

  /// Converts environment to [EnvModel].
  EnvModel toModel() => EnvModel(
        name: name,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        razorpayKeyId: razorpayKeyId,
        apiBaseUrl: apiBaseUrl,
      );

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

  static const String _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _razorpayKeyIdDefine = String.fromEnvironment('RAZORPAY_KEY_ID');

  static AppEnvironment get environment => AppEnvironment.current;

  /// Returns active [EnvModel] populated from environment and dart-defines.
  static EnvModel get activeEnv => EnvModel(
        name: environment.name,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        razorpayKeyId: razorpayKeyId,
        apiBaseUrl: apiBaseUrl,
      );

  static String get supabaseUrl =>
      _supabaseUrlDefine.isNotEmpty ? _supabaseUrlDefine : environment.supabaseUrl;
  static String get supabaseAnonKey =>
      _supabaseAnonKeyDefine.isNotEmpty ? _supabaseAnonKeyDefine : environment.supabaseAnonKey;
  static String get razorpayKeyId =>
      _razorpayKeyIdDefine.isNotEmpty ? _razorpayKeyIdDefine : environment.razorpayKeyId;
  static String get apiBaseUrl => environment.apiBaseUrl;
  static String get appName => 'BookMySpace';

  /// Environment helpers
  static bool get isDevelopment =>
      environment == AppEnvironment.development || environment == AppEnvironment.local;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isRazorpayTestMode => razorpayKeyId.startsWith('rzp_test_');

  /// Safe diagnostic summary of active environment settings (no sensitive keys exposed).
  static Map<String, dynamic> get environmentSummary => activeEnv.toSummaryMap();

  /// Booking hold duration before automatic expiry (server enforced too).
  static const Duration bookingHoldDuration = Duration(minutes: 10);
  static const int requestTimeoutSeconds = 20;
  static const int maxRetries = 3;
}

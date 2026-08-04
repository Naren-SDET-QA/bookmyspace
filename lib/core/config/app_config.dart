import 'package:flutter/foundation.dart';

/// Supported runtime environments.
///
/// Secrets must never be committed. Real values come from
/// `--dart-define` flags at build time (see the `--dart-define` examples in
/// the README). Supabase values are always required dart-defines.
enum AppEnvironment {
  local(
    name: 'local',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'http://127.0.0.1:8080',
  ),
  development(
    name: 'development',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  testing(
    name: 'testing',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  staging(
    name: 'staging',
    razorpayKeyId: 'rzp_test_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  ),
  production(
    name: 'production',
    razorpayKeyId: 'rzp_live_PLACEHOLDER',
    apiBaseUrl: 'https://YOUR_PROJECT.supabase.co/functions/v1',
  );

  const AppEnvironment({
    required this.name,
    required this.razorpayKeyId,
    required this.apiBaseUrl,
  });

  final String name;
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

  static const String _supabaseUrlDefine = String.fromEnvironment(
    'SUPABASE_URL',
  );
  static const String _supabaseKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _devCustomerEmail = String.fromEnvironment(
    'DEV_CUSTOMER_EMAIL',
  );
  static const String _devCustomerPassword = String.fromEnvironment(
    'DEV_CUSTOMER_PASSWORD',
  );
  static const String _devOwnerEmail = String.fromEnvironment(
    'DEV_OWNER_EMAIL',
  );
  static const String _devOwnerPassword = String.fromEnvironment(
    'DEV_OWNER_PASSWORD',
  );
  static const String _devAdminEmail = String.fromEnvironment(
    'DEV_ADMIN_EMAIL',
  );
  static const String _devAdminPassword = String.fromEnvironment(
    'DEV_ADMIN_PASSWORD',
  );
  static const String _razorpayKeyIdDefine = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
  );

  static AppEnvironment get environment => AppEnvironment.current;
  static String get supabaseUrl => _supabaseUrlDefine.trim();
  static String get supabaseAnonKey => _supabaseKeyDefine.trim();
  static bool get hasSupabaseConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Compile-time gated test login. It is intentionally unavailable in
  /// release/profile builds and every environment except development.
  static bool get developmentTestLoginEnabled =>
      developmentTestCredentials.isNotEmpty;

  static Map<String, ({String email, String password})>
  get developmentTestCredentials {
    if (!isDevelopmentTestEnvironmentAllowed(
      environment: environment,
      releaseMode: kReleaseMode,
      profileMode: kProfileMode,
    )) {
      return const {};
    }
    return {
      if (_devCustomerEmail.trim().isNotEmpty &&
          _devCustomerPassword.isNotEmpty)
        'customer': (
          email: _devCustomerEmail.trim(),
          password: _devCustomerPassword,
        ),
      if (_devOwnerEmail.trim().isNotEmpty && _devOwnerPassword.isNotEmpty)
        'owner': (email: _devOwnerEmail.trim(), password: _devOwnerPassword),
      if (_devAdminEmail.trim().isNotEmpty && _devAdminPassword.isNotEmpty)
        'admin': (email: _devAdminEmail.trim(), password: _devAdminPassword),
    };
  }

  static bool isDevelopmentTestEnvironmentAllowed({
    required AppEnvironment environment,
    required bool releaseMode,
    required bool profileMode,
  }) =>
      !releaseMode && !profileMode && environment == AppEnvironment.development;

  static bool isDevelopmentTestLoginAllowed({
    required AppEnvironment environment,
    required bool releaseMode,
    required bool profileMode,
    required String email,
    required String password,
  }) =>
      isDevelopmentTestEnvironmentAllowed(
        environment: environment,
        releaseMode: releaseMode,
        profileMode: profileMode,
      ) &&
      email.trim().isNotEmpty &&
      password.isNotEmpty;

  static void requireSupabaseConfiguration() {
    if (!hasSupabaseConfiguration) {
      throw StateError(
        'Missing Supabase configuration. Start the app with '
        '--dart-define=SUPABASE_URL=<project-url> and '
        '--dart-define=SUPABASE_ANON_KEY=<publishable-key>.',
      );
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        supabaseUrl.toLowerCase().contains('your_project')) {
      throw StateError('SUPABASE_URL must be a valid Supabase project URL.');
    }
    if (supabaseAnonKey.contains('PLACEHOLDER') ||
        supabaseAnonKey.contains('ANON_KEY')) {
      throw StateError(
        'SUPABASE_ANON_KEY must be the project publishable/anon key.',
      );
    }
  }

  /// Razorpay key id (public). Override with `--dart-define=RAZORPAY_KEY_ID=...`
  /// so checkout uses the same test key as the Edge Functions.
  static String get razorpayKeyId {
    final fromDefine = _razorpayKeyIdDefine.trim();
    if (fromDefine.isNotEmpty) return fromDefine;
    return environment.razorpayKeyId;
  }

  static bool get hasRazorpayConfiguration =>
      razorpayKeyId.isNotEmpty && !razorpayKeyId.contains('PLACEHOLDER');
  static String get apiBaseUrl => environment.apiBaseUrl;
  static String get appName => 'BookMySpace';

  /// Booking hold duration before automatic expiry (server enforced too).
  static const Duration bookingHoldDuration = Duration(minutes: 10);
  static const int requestTimeoutSeconds = 20;
  static const int maxRetries = 3;

  // --- Open-source maps (OSM / Nominatim / OSRM). No paid API required. ---

  static const String _osmTileUrlDefine = String.fromEnvironment(
    'OSM_TILE_URL_TEMPLATE',
  );
  static const String _nominatimUrlDefine = String.fromEnvironment(
    'NOMINATIM_BASE_URL',
  );
  static const String _osrmUrlDefine = String.fromEnvironment('OSRM_BASE_URL');
  static const String _mapsUserAgentDefine = String.fromEnvironment(
    'MAPS_USER_AGENT',
  );
  static const String _useGooglePlacesDefine = String.fromEnvironment(
    'USE_GOOGLE_PLACES',
  );
  static const String _googlePlacesKeyDefine = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
  );

  /// Raster tile URL template (`{z}/{x}/{y}`). Defaults to OSM public tiles.
  static String get osmTileUrlTemplate {
    final v = _osmTileUrlDefine.trim();
    return v.isNotEmpty
        ? v
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Nominatim base URL (no trailing slash).
  static String get nominatimBaseUrl {
    final v = _nominatimUrlDefine.trim();
    return v.isNotEmpty ? v : 'https://nominatim.openstreetmap.org';
  }

  /// OSRM base URL (no trailing slash).
  static String get osrmBaseUrl {
    final v = _osrmUrlDefine.trim();
    return v.isNotEmpty ? v : 'https://router.project-osrm.org';
  }

  /// Required by Nominatim usage policy — identifies BookMySpace.
  static String get mapsUserAgent {
    final v = _mapsUserAgentDefine.trim();
    return v.isNotEmpty
        ? v
        : 'BookMySpace/1.0 (https://github.com/bookmyspace; maps@bookmyspace.app)';
  }

  /// Package name passed to flutter_map TileLayer user-agent.
  static const String mapsPackageName = 'com.bookmyspace.app';

  /// Google Places enrichment/geocoding — OFF by default; never required.
  static bool get useGooglePlaces {
    final flag = _useGooglePlacesDefine.trim().toLowerCase();
    if (flag == 'true' || flag == '1') {
      return googlePlacesApiKey.isNotEmpty;
    }
    return false;
  }

  /// Optional Places API key via `--dart-define=GOOGLE_PLACES_API_KEY=...`.
  static String get googlePlacesApiKey => _googlePlacesKeyDefine.trim();
}

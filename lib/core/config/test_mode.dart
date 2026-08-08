import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Compile-time Test Mode configuration.
///
/// Test Mode is turned on at build time with:
/// `--dart-define=TEST_MODE=true`
///
/// When enabled the app uses the existing development backend (it never
/// creates local servers, proxies, mocks or fake auth), routes through a
/// logging HTTP client, exposes a hidden debug menu, seeds test accounts and
/// switches on feature flags. All toggles below are compile-time constants so
/// they are eliminated in release builds that are not built for testing.
abstract final class TestMode {
  /// Master switch. Defaults to enabled in debug/profile builds when not
  /// explicitly disabled, and is always off in release unless explicitly set.
  static const bool enabled = bool.fromEnvironment(
    'TEST_MODE',
    defaultValue: kDebugMode,
  );

  /// Hidden debug menu reachable from Settings (7 taps on the About tile).
  static const bool debugMenuEnabled = bool.fromEnvironment(
    'DEBUG_MENU',
    defaultValue: enabled,
  );

  /// Log every HTTP request/response the app makes to its backend.
  static const bool networkLoggingEnabled = bool.fromEnvironment(
    'NETWORK_LOGGING',
    defaultValue: enabled,
  );

  /// Log high-level API calls (repository → Supabase).
  static const bool apiLoggingEnabled = bool.fromEnvironment(
    'API_LOGGING',
    defaultValue: enabled,
  );

  /// Surface crash/catch errors in the debug log (Crashlytics stays on).
  static const bool crashLoggingEnabled = bool.fromEnvironment(
    'CRASH_LOGGING',
    defaultValue: enabled,
  );

  /// Record screen/request timings in the debug log.
  static const bool performanceLoggingEnabled = bool.fromEnvironment(
    'PERFORMANCE_LOGGING',
    defaultValue: enabled,
  );

  /// Allow the "Reset test data" action from the debug menu.
  static const bool testDataResetEnabled = bool.fromEnvironment(
    'TEST_DATA_RESET',
    defaultValue: enabled,
  );

  /// Push notification debug tools (Firebase Messaging debug token/logs).
  static const bool pushDebugEnabled = bool.fromEnvironment(
    'PUSH_DEBUG',
    defaultValue: enabled,
  );

  /// Deep link debug tools (log navigations / incoming links).
  static const bool deepLinkDebugEnabled = bool.fromEnvironment(
    'DEEP_LINK_DEBUG',
    defaultValue: enabled,
  );

  /// Active backend environment in Test Mode: the existing development
  /// backend. The app never swaps in a local or mock backend.
  static AppEnvironment get environment => AppEnvironment.development;

  /// Backend URL used when Test Mode is enabled.
  static String get supabaseUrl => environment.supabaseUrl;

  /// Backend anon key used when Test Mode is enabled.
  static String get supabaseAnonKey => environment.supabaseAnonKey;
}

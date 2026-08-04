import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around Firebase Crashlytics for error reporting.
class CrashlyticsService {
  CrashlyticsService._();

  static final FirebaseCrashlytics _instance = FirebaseCrashlytics.instance;

  /// Initialize Crashlytics and set up error handlers.
  static Future<void> init({
    bool collectReports = true,
    bool recordFlutterFatalErrors = true,
  }) async {
    if (kIsWeb) {
      // Crashlytics on web requires additional setup
      debugPrint('Crashlytics: Web platform - limited support');
      return;
    }

    try {
      await _instance.setCrashlyticsCollectionEnabled(collectReports);

      if (recordFlutterFatalErrors) {
        FlutterError.onError = _recordFlutterError;
      }

      PlatformDispatcher.instance.onError = (error, stack) {
        recordError(error, stack, fatal: true);
        return true;
      };

      debugPrint('Crashlytics initialized');
    } catch (e) {
      debugPrint('Crashlytics init failed: $e');
    }
  }

  /// Record a Flutter framework error.
  static void _recordFlutterError(FlutterErrorDetails details) {
    _instance.recordFlutterFatalError(details);
    debugPrint('Crashlytics recorded Flutter error: ${details.exception}');
  }

  /// Record a non-fatal error.
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object>? information,
    bool fatal = false,
  }) {
    if (kIsWeb) return;

    _instance.recordError(
      error,
      stack,
      reason: reason,
      information: information ?? [],
      fatal: fatal,
    );
  }

  /// Record a custom exception with context.
  static void recordException(
    Exception exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, Object?>? extra,
  }) {
    final info = <Object>[
      if (context != null) 'context: $context',
      if (extra != null) ...extra.entries.map((e) => '${e.key}: ${e.value}'),
    ];

    recordError(
      exception,
      stackTrace,
      reason: 'Exception: ${exception.runtimeType}',
      information: info.isNotEmpty ? info : null,
      fatal: false,
    );
  }

  /// Set a custom user ID for crash reports.
  static Future<void> setUserId(String userId) async {
    if (kIsWeb) return;
    await _instance.setUserIdentifier(userId);
  }

  /// Add a custom key-value pair to crash reports.
  static Future<void> setCustomKey(String key, Object value) async {
    if (kIsWeb) return;
    await _instance.setCustomKey(key, value);
  }

  /// Log a custom message (appears in crash reports).
  static Future<void> log(String message) async {
    if (kIsWeb) return;
    await _instance.log(message);
  }

  /// Check if Crashlytics is enabled.
  static bool get isEnabled => !kIsWeb;
}

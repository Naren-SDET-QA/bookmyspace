import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'crashlytics_service.dart';
import 'performance_service.dart';

/// Centralized error logging and monitoring.
///
/// Combines Crashlytics, Performance, and custom logging.
class ErrorLogger {
  ErrorLogger._();

  static bool _initialized = false;

  /// Initialize all monitoring services.
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await CrashlyticsService.init(
        collectReports: !kDebugMode,
        recordFlutterFatalErrors: true,
      );

      await PerformanceService.init();

      _initialized = true;
      debugPrint('ErrorLogger initialized');
    } catch (e) {
      debugPrint('ErrorLogger init failed: $e');
    }
  }

  /// Log an error with full context.
  ///
  /// - Records to Crashlytics
  /// - Logs to console in debug mode
  static void logError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, Object?>? extra,
    bool fatal = false,
  }) {
    // Console logging
    debugPrint('🔴 ERROR${fatal ? ' (FATAL)' : ''}: $error');
    if (context != null) debugPrint('   Context: $context');
    if (stackTrace != null) debugPrint('   Stack: $stackTrace');

    // Crashlytics
    CrashlyticsService.recordError(
      error,
      stackTrace,
      reason: context,
      information: extra?.entries.map((e) => '${e.key}: ${e.value}').toList(),
      fatal: fatal,
    );
  }

  /// Log a caught exception.
  static void logException(
    Exception exception, {
    StackTrace? stackTrace,
    String? context,
    Map<String, Object?>? extra,
  }) {
    logError(
      exception,
      stackTrace,
      context: context ?? 'Exception: ${exception.runtimeType}',
      extra: extra,
      fatal: false,
    );
  }

  /// Log a custom message to Crashlytics.
  static void logMessage(String message, {String? context}) {
    debugPrint('📝 LOG: $message');
    CrashlyticsService.log('$message${context != null ? ' [$context]' : ''}');
  }

  /// Set the current user ID for crash reports.
  static Future<void> setUserId(String userId) async {
    await CrashlyticsService.setUserId(userId);
  }

  /// Clear user ID on logout.
  static Future<void> clearUserId() async {
    await CrashlyticsService.setUserId('');
  }

  /// Add a custom key-value pair to crash reports.
  static Future<void> setCustomKey(String key, Object value) async {
    await CrashlyticsService.setCustomKey(key, value);
  }

  /// Start a performance trace for a screen/view.
  static Trace? startScreenTrace(String screenName) {
    return PerformanceService.startScreenTrace(screenName);
  }

  /// Start a performance trace for a network request.
  static HttpMetric? startHttpTrace(String url, String method) {
    return PerformanceService.startHttpTrace(url, method.toUpperCase());
  }

  /// Record a custom performance metric.
  static Future<void> recordMetric(
    String traceName,
    String metricName,
    int value,
  ) async {
    await PerformanceService.recordMetric(traceName, metricName, value);
  }
}
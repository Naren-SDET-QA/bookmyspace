import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Wrapper around Firebase Performance Monitoring.
class PerformanceService {
  PerformanceService._();

  static final FirebasePerformance _instance = FirebasePerformance.instance;

  /// Initialize Performance Monitoring.
  static Future<void> init() async {
    if (kIsWeb) {
      debugPrint('Performance: Web platform - limited support');
      return;
    }

    try {
      await _instance.setPerformanceCollectionEnabled(true);
      debugPrint('Performance monitoring initialized');
    } catch (e) {
      debugPrint('Performance init failed: $e');
    }
  }

  /// Start a custom trace.
  static Trace? startTrace(String name) {
    if (kIsWeb) return null;
    try {
      final trace = _instance.newTrace(name);
      trace.start();
      return trace;
    } catch (e) {
      debugPrint('Performance trace start failed: $e');
      return null;
    }
  }

  /// Stop a custom trace.
  static void stopTrace(Trace? trace) {
    if (trace == null) return;
    try {
      trace.stop();
    } catch (e) {
      debugPrint('Performance trace stop failed: $e');
    }
  }

  /// Increment a counter in a trace.
  static void incrementCounter(Trace? trace, String name, int increment) {
    if (trace == null) return;
    try {
      trace.incrementMetric(name, increment);
    } catch (e) {
      debugPrint('Performance increment failed: $e');
    }
  }

  /// Record a screen view trace.
  static Trace? startScreenTrace(String screenName) {
    if (kIsWeb) return null;
    try {
      final trace = _instance.newTrace('screen_view_$screenName');
      trace.putAttribute('screen_name', screenName);
      trace.start();
      return trace;
    } catch (e) {
      debugPrint('Screen trace start failed: $e');
      return null;
    }
  }

  /// Record an HTTP request trace.
  static HttpMetric? startHttpTrace(String url, String method) {
    if (kIsWeb) return null;
    try {
      final httpMethod = HttpMethod.values.firstWhere(
        (m) => m.name.toLowerCase() == method.toLowerCase(),
        orElse: () => HttpMethod.Get,
      );
      final metric = _instance.newHttpMetric(url, httpMethod);
      metric.start();
      return metric;
    } catch (e) {
      debugPrint('HTTP metric start failed: $e');
      return null;
    }
  }

  /// Record a custom metric.
  static Future<void> recordMetric(
    String traceName,
    String metricName,
    int value,
  ) async {
    if (kIsWeb) return;
    try {
      final trace = _instance.newTrace(traceName);
      trace.incrementMetric(metricName, value);
      await trace.stop();
    } catch (e) {
      debugPrint('Record metric failed: $e');
    }
  }

  /// Set user attributes for performance segmentation.
  static Future<void> setUserAttribute(String key, String value) async {
    if (kIsWeb) return;
    try {
      await _instance.setPerformanceCollectionEnabled(true);
      // Note: setAttribute is not available in current version
      // Use trace.putAttribute instead for individual traces
    } catch (e) {
      debugPrint('Set attribute failed: $e');
    }
  }
}
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppHealthStatus { healthy, degraded, failed, unknown }

class AppHealthResult {
  AppHealthResult({
    required this.status,
    required this.message,
    this.latency,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? _now;

  static DateTime get _now => DateTime.now().toUtc();

  final AppHealthStatus status;
  final String message;
  final Duration? latency;
  final DateTime checkedAt;
}

abstract interface class AppHealthCheck {
  String get id;
  String get displayName;
  bool get critical;
  Future<AppHealthResult> check();
}

class FunctionHealthCheck implements AppHealthCheck {
  const FunctionHealthCheck({
    required this.id,
    required this.displayName,
    required this.checker,
    this.critical = false,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final bool critical;
  final Future<AppHealthResult> Function() checker;

  @override
  Future<AppHealthResult> check() => checker();
}

class NetworkHealthCheck extends FunctionHealthCheck {
  NetworkHealthCheck(Future<void> Function() probe)
    : super(
        id: 'network',
        displayName: 'Network',
        checker: () async {
          await probe();
          return AppHealthResult(
            status: AppHealthStatus.healthy,
            message: 'Available',
          );
        },
      );
}

class SupabaseHealthCheck extends FunctionHealthCheck {
  SupabaseHealthCheck(Future<void> Function() probe)
    : super(
        id: 'supabase',
        displayName: 'Supabase',
        critical: true,
        checker: () async {
          await probe();
          return AppHealthResult(
            status: AppHealthStatus.healthy,
            message: 'Available',
          );
        },
      );
}

class ConfigurationHealthCheck extends FunctionHealthCheck {
  ConfigurationHealthCheck(Future<void> Function() probe)
    : super(
        id: 'configuration',
        displayName: 'Configuration',
        checker: () async {
          await probe();
          return AppHealthResult(
            status: AppHealthStatus.healthy,
            message: 'Available',
          );
        },
      );
}

/// The initial live checks. Probes are deliberately independent, read-only,
/// and run in parallel through [AppHealthService].
List<AppHealthCheck> liveAppHealthChecks(SupabaseClient client) {
  Future<void> probe() async {
    await client.from('venue_categories').select('id').limit(1);
  }

  Future<void> configurationProbe() async {
    await client
        .from('module_feature_configs')
        .select('module_key')
        .eq('module_key', 'auth')
        .limit(1);
  }

  return [
    NetworkHealthCheck(probe),
    SupabaseHealthCheck(probe),
    ConfigurationHealthCheck(configurationProbe),
  ];
}

class AppHealthSnapshot {
  const AppHealthSnapshot({
    this.status = AppHealthStatus.unknown,
    this.results = const {},
    this.checkedAt,
    this.isChecking = false,
  });

  final AppHealthStatus status;
  final Map<String, AppHealthResult> results;
  final DateTime? checkedAt;
  final bool isChecking;
}

class AppHealthService {
  AppHealthService({
    Iterable<AppHealthCheck> checks = const [],
    this.timeout = const Duration(seconds: 3),
  }) : checks = List.unmodifiable(checks);

  final List<AppHealthCheck> checks;
  final Duration timeout;
  Future<AppHealthSnapshot>? _running;

  Future<AppHealthSnapshot> refresh() => _running ??= _scan().whenComplete(() {
    _running = null;
  });

  Future<AppHealthSnapshot> _scan() async {
    final values = await Future.wait(checks.map(_runSafely));
    final results = <String, AppHealthResult>{
      for (var i = 0; i < checks.length; i++) checks[i].id: values[i],
    };
    return AppHealthSnapshot(
      status: _overall(results.values),
      results: results,
      checkedAt: DateTime.now().toUtc(),
    );
  }

  Future<AppHealthResult> _runSafely(AppHealthCheck check) async {
    final started = DateTime.now();
    try {
      final result = await check.check().timeout(timeout);
      return AppHealthResult(
        status: result.status,
        message: _safeMessage(result.status, result.message),
        latency: DateTime.now().difference(started),
      );
    } on TimeoutException {
      return AppHealthResult(
        status: AppHealthStatus.degraded,
        message: 'The check timed out.',
      );
    } catch (_) {
      return AppHealthResult(
        status: AppHealthStatus.failed,
        message: 'The service could not be checked.',
      );
    }
  }

  static String _safeMessage(AppHealthStatus status, String message) {
    if (status == AppHealthStatus.healthy) return 'Available';
    if (message.trim().isEmpty) return 'Temporarily unavailable.';
    return message.length > 160 ? '${message.substring(0, 160)}…' : message;
  }

  static AppHealthStatus _overall(Iterable<AppHealthResult> values) {
    final list = values.toList();
    if (list.isEmpty || list.any((e) => e.status == AppHealthStatus.unknown)) {
      return AppHealthStatus.unknown;
    }
    if (list.any((e) => e.status == AppHealthStatus.failed)) {
      return AppHealthStatus.failed;
    }
    if (list.any((e) => e.status == AppHealthStatus.degraded)) {
      return AppHealthStatus.degraded;
    }
    return AppHealthStatus.healthy;
  }
}

final appHealthServiceProvider = Provider<AppHealthService>((ref) {
  return AppHealthService(checks: liveAppHealthChecks(Supabase.instance.client));
});

final appHealthProvider = FutureProvider<AppHealthSnapshot>((ref) {
  return ref.watch(appHealthServiceProvider).refresh();
});

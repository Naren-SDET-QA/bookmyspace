import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/health/app_health.dart';

AppHealthResult result(AppHealthStatus status, [String message = 'ok']) =>
    AppHealthResult(status: status, message: message);

void main() {
  test('healthy checks produce a healthy snapshot', () async {
    final service = AppHealthService(checks: [
      FunctionHealthCheck(id: 'network', displayName: 'Network', checker: () async => result(AppHealthStatus.healthy)),
    ]);
    final snapshot = await service.refresh();
    expect(snapshot.status, AppHealthStatus.healthy);
    expect(snapshot.results['network']!.message, 'Available');
  });

  test('degraded and failed checks are reflected in overall status', () async {
    final service = AppHealthService(checks: [
      FunctionHealthCheck(id: 'a', displayName: 'A', checker: () async => result(AppHealthStatus.degraded)),
      FunctionHealthCheck(id: 'b', displayName: 'B', checker: () async => result(AppHealthStatus.healthy)),
    ]);
    expect((await service.refresh()).status, AppHealthStatus.degraded);
    final failed = AppHealthService(checks: [
      FunctionHealthCheck(id: 'b', displayName: 'B', checker: () async => result(AppHealthStatus.failed, 'SQL secret should not leak')),
    ]);
    final snapshot = await failed.refresh();
    expect(snapshot.status, AppHealthStatus.failed);
    expect(snapshot.results['b']!.message.length, lessThanOrEqualTo(160));
  });

  test('unknown is used when no checks are registered', () async {
    expect((await AppHealthService().refresh()).status, AppHealthStatus.unknown);
  });

  test('timeout becomes bounded degraded state', () async {
    final service = AppHealthService(
      timeout: const Duration(milliseconds: 10),
      checks: [FunctionHealthCheck(id: 'slow', displayName: 'Slow', checker: () async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return result(AppHealthStatus.healthy);
      })],
    );
    final snapshot = await service.refresh();
    expect(snapshot.results['slow']!.status, AppHealthStatus.degraded);
  });

  test('refresh shares concurrent scans', () async {
    var calls = 0;
    final service = AppHealthService(checks: [FunctionHealthCheck(
      id: 'one', displayName: 'One', checker: () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return result(AppHealthStatus.healthy);
      },
    )]);
    final values = await Future.wait([service.refresh(), service.refresh()]);
    expect(calls, 1);
    expect(values[0].status, AppHealthStatus.healthy);
  });

  test('one failed check does not prevent other checks from completing', () async {
    final service = AppHealthService(checks: [
      FunctionHealthCheck(id: 'bad', displayName: 'Bad', checker: () async => throw StateError('internal')),
      FunctionHealthCheck(id: 'good', displayName: 'Good', checker: () async => result(AppHealthStatus.healthy)),
    ]);
    final snapshot = await service.refresh();
    expect(snapshot.results['bad']!.status, AppHealthStatus.failed);
    expect(snapshot.results['good']!.status, AppHealthStatus.healthy);
  });

  test('live adapter contracts map successful probes to healthy results', () async {
    final checks = <AppHealthCheck>[
      NetworkHealthCheck(() async {}),
      SupabaseHealthCheck(() async {}),
      ConfigurationHealthCheck(() async {}),
    ];
    final snapshot = await AppHealthService(checks: checks).refresh();
    expect(snapshot.status, AppHealthStatus.healthy);
    expect(snapshot.results.keys, containsAll(['network', 'supabase', 'configuration']));
  });

  test('live adapter failures are isolated and safely mapped', () async {
    final snapshot = await AppHealthService(checks: [
      NetworkHealthCheck(() async => throw StateError('private backend detail')),
      SupabaseHealthCheck(() async {}),
      ConfigurationHealthCheck(() async => throw StateError('secret detail')),
    ]).refresh();
    expect(snapshot.results['network']!.status, AppHealthStatus.failed);
    expect(snapshot.results['network']!.message, 'The service could not be checked.');
    expect(snapshot.results['supabase']!.status, AppHealthStatus.healthy);
    expect(snapshot.results['configuration']!.message, 'The service could not be checked.');
  });
}

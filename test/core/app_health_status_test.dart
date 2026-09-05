import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/health/app_health.dart';
import 'package:bookmyspace/core/health/app_health_status.dart';

void main() {
  testWidgets('shows healthy status without sensitive details', (tester) async {
    final service = AppHealthService(
      checks: [
        FunctionHealthCheck(
          id: 'network',
          displayName: 'Network',
          checker: () async =>
              AppHealthResult(status: AppHealthStatus.healthy, message: 'ok'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appHealthServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: Scaffold(body: AppHealthStatusWidget())),
      ),
    );
    await tester.pumpAndSettle();
    // Healthy / loading states stay hidden so the status bar and home
    // header are not covered by a persistent availability banner.
    expect(find.text('All services available'), findsNothing);
    expect(
      find.text('Some features may be temporarily unavailable.'),
      findsNothing,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.textContaining('password'), findsNothing);
  });

  testWidgets('shows retry for degraded state', (tester) async {
    final service = AppHealthService(
      checks: [
        FunctionHealthCheck(
          id: 'network',
          displayName: 'Network',
          checker: () async => AppHealthResult(
            status: AppHealthStatus.degraded,
            message: 'offline',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appHealthServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: Scaffold(body: AppHealthStatusWidget())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Some features may be temporarily unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

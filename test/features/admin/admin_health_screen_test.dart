import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/health/app_health.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_health_screen.dart';

void main() {
  testWidgets('renders dynamic health checks and summary', (tester) async {
    final service = AppHealthService(checks: [
      FunctionHealthCheck(id: 'network', displayName: 'Network', checker: () async => AppHealthResult(status: AppHealthStatus.healthy, message: 'ok')),
      FunctionHealthCheck(id: 'storage', displayName: 'Storage', checker: () async => AppHealthResult(status: AppHealthStatus.degraded, message: 'limited')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [appHealthServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: AdminHealthScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('network'), findsOneWidget);
    expect(find.text('storage'), findsOneWidget);
    expect(find.textContaining('Healthy: 1'), findsOneWidget);
    expect(find.text('Run Diagnostic'), findsOneWidget);
  });
}

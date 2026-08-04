import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner/domain/owner.dart';
import 'package:bookmyspace/features/owner/domain/owner_dashboard_stats.dart';
import 'package:bookmyspace/features/owner/presentation/owner_providers.dart';
import 'package:bookmyspace/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner dashboard shows live stats from mocked provider', (
    tester,
  ) async {
    const owner = Owner(
      id: 'o1',
      userId: 'u1',
      email: 'owner@example.com',
      name: 'Test Owner',
    );
    const stats = OwnerDashboardStats(
      monthlyRevenue: 12500,
      totalBookings: 8,
      pendingApprovals: 2,
      todayBookings: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentOwnerProvider.overrideWith((ref) => Future.value(owner)),
          ownerDashboardStatsProvider.overrideWith(
            (ref) => Future.value(stats),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Owner'), findsOneWidget);
    expect(find.text('₹12.5K'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Offline Booking'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Offline Booking'), findsOneWidget);
  });
}

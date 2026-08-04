import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin dashboard shows all module tiles', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform Administration'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Payments / Refunds'), findsOneWidget);
    expect(find.text('Audit Logs'), findsOneWidget);
  });

  testWidgets('admin module screen shows rows from provider override', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminModuleRowsProvider(AdminModule.users).overrideWith(
            (ref) => Future.value([
              {
                'id': '1',
                'email': 'user@example.com',
                '_source': 'profiles',
              },
            ]),
          ),
        ],
        child: const MaterialApp(
          home: AdminModuleScreen(module: AdminModule.users),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('email: user@example.com'), findsOneWidget);
  });
}

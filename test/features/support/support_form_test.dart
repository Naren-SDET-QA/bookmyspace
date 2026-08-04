import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/support/presentation/screens/support_screen.dart';
import 'package:bookmyspace/features/support/presentation/support_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_support_repository.dart';

void main() {
  testWidgets('support ticket dialog blocks invalid subject and description', (
    tester,
  ) async {
    final supportRepo = MockSupportRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportTicketRepositoryProvider.overrideWithValue(supportRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SupportTicketsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Ticket'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Subject is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);
    expect(supportRepo.lastCreate, isNull);
  });

  testWidgets('support ticket dialog rejects short subject', (tester) async {
    final supportRepo = MockSupportRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportTicketRepositoryProvider.overrideWithValue(supportRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SupportTicketsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Ticket'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Subject'), 'Hi');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'This is a long enough description for support.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.textContaining('at least 3 characters'), findsOneWidget);
    expect(supportRepo.lastCreate, isNull);
  });
}

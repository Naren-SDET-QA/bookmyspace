import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner/presentation/screens/owner_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner registration blocks invalid email and password', (
    tester,
  ) async {
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
          home: OwnerRegistrationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bad');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'A');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter a valid name (2-50 characters)'), findsOneWidget);
    expect(
      find.text('Password must be at least 8 characters'),
      findsOneWidget,
    );
  });
}

import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

Widget _wrap(MockAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(),
    ),
  );
}

void main() {
  testWidgets('development login control follows the compile-time gate', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    for (final role in ['Customer', 'Owner', 'Admin']) {
      expect(
        find.text('$role Test Login'),
        AppConfig.developmentTestCredentials.containsKey(role.toLowerCase())
            ? findsOneWidget
            : findsNothing,
      );
    }
    expect(
      find.textContaining('TEST MODE'),
      AppConfig.developmentTestLoginEnabled ? findsOneWidget : findsNothing,
    );
    repo.dispose();
  });

  testWidgets('sends email OTP then verifies and shows success path', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(repo.signInCount, 1);
    expect(find.textContaining('verification code'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '123456');
    await tester.ensureVisible(find.text('Verify & log in'));
    await tester.tap(find.text('Verify & log in'));
    await tester.pumpAndSettle();

    expect(repo.verifyCount, 1);
    expect(repo.currentUser?.email, 'a@b.com');
    repo.dispose();
  });

  testWidgets('toggles between email and phone channels', (tester) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Phone'));
    await tester.tap(find.text('Phone'));

    await tester.enterText(find.byType(TextFormField).first, '9999999999');
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(repo.signInCount, 1);
    repo.dispose();
  });

  testWidgets('shows an error when OTP send fails', (tester) async {
    final repo = MockAuthRepository()..failSignIn = true;
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OTP send failed'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('prevents OTP resends until the 60 second cooldown ends', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.ensureVisible(find.text('Send code'));
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(repo.signInCount, 1);
    expect(find.text('Resend code in 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend code in 59s'), findsOneWidget);
    await tester.tap(find.text('Resend code in 59s'));
    await tester.pump();
    expect(repo.signInCount, 1);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Resend code'), findsOneWidget);
    repo.dispose();
  });
}

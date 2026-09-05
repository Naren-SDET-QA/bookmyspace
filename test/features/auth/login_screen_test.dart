import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

Widget _wrap(
  MockAuthRepository repo, {
  AuthConfiguration config = const AuthConfiguration(
    authenticationEnabled: true,
    emailLoginEnabled: true,
    emailOtpEnabled: true,
    phoneLoginEnabled: true,
    phoneOtpEnabled: true,
  ),
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authConfigurationProvider.overrideWith((ref) async => config),
    ],
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
  testWidgets('sends email OTP then verifies and shows success path', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
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

    await tester.tap(find.text('Phone'));

    await tester.enterText(find.byType(TextFormField).first, '9999999999');
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
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OTP send failed'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('shows forgot password when password login is enabled', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(
      _wrap(
        repo,
        config: const AuthConfiguration(
          authenticationEnabled: true,
          emailLoginEnabled: true,
          passwordLoginEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
    repo.dispose();
  });
}

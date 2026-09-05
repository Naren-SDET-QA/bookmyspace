import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/core/validators/app_validators.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:bookmyspace/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_auth_repository.dart';

Widget _wrap(MockAuthRepository repo, {required Widget home}) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: home,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  test('password confirmation uses existing validator rules', () {
    expect(AppValidators.confirmPassword('password1', 'password1'), isNull);
    expect(AppValidators.confirmPassword('short', 'short'), isNotNull);
    expect(AppValidators.confirmPassword('password1', 'password2'), isNotNull);
  });

  test('native password-reset redirect reuses the existing app scheme', () {
    expect(
      AppConfig.passwordResetRedirectUri,
      AppConfig.nativeAuthRedirectUri,
    );
    expect(
      AppConfig.passwordResetRedirectUri,
      contains('com.bookmyspace.bookmyspace://'),
    );
  });

  test('resolveAppRedirect keeps reset-password public and recovery-safe', () {
    expect(
      resolveAppRedirect(
        location: AppRoutes.forgotPassword,
        currentUser: null,
        authReady: true,
      ),
      isNull,
    );
    expect(
      resolveAppRedirect(
        location: AppRoutes.resetPassword,
        currentUser: null,
        authReady: true,
      ),
      isNull,
    );
    expect(
      resolveAppRedirect(
        location: AppRoutes.resetPassword,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        authReady: true,
      ),
      isNull,
    );
    expect(
      resolveAppRedirect(
        location: AppRoutes.login,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        authReady: true,
      ),
      AppRoutes.shell,
    );
  });

  testWidgets('forgot password sends a reset email and shows success', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo, home: const ForgotPasswordScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      'user@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(repo.passwordResetCount, 1);
    expect(repo.lastResetEmail, 'user@example.com');
    expect(find.text('Check your email'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('forgot password shows an error when the request fails', (
    tester,
  ) async {
    final repo = MockAuthRepository()..failPasswordReset = true;
    await tester.pumpWidget(_wrap(repo, home: const ForgotPasswordScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot_password_email')),
      'user@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('reset failed'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('reset password validates mismatch and updates on success', (
    tester,
  ) async {
    final repo = MockAuthRepository(
      initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
    );
    await tester.pumpWidget(_wrap(repo, home: const ResetPasswordScreen()));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('reset_password_field')), 'password1');
    await tester.enterText(
      find.byKey(const Key('reset_password_confirm_field')),
      'password2',
    );
    await tester.tap(find.byKey(const Key('reset_password_submit')));
    await tester.pump();
    expect(repo.updatePasswordCount, 0);

    await tester.enterText(
      find.byKey(const Key('reset_password_confirm_field')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('reset_password_submit')));
    await tester.pump();
    expect(repo.updatePasswordCount, 1);
    expect(repo.lastNewPassword, 'password1');
    expect(repo.currentUser, isNull);
    expect(find.text('Password updated'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('reset password without a recovery session shows expired state', (
    tester,
  ) async {
    final repo = MockAuthRepository();
    await tester.pumpWidget(_wrap(repo, home: const ResetPasswordScreen()));
    await tester.pump();
    expect(find.textContaining('invalid or has expired'), findsOneWidget);
    repo.dispose();
  });
}

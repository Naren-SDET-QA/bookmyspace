import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase initialization explicitly enables PKCE URI handling', () {
    final source = File(
      'lib/features/auth/presentation/auth_providers.dart',
    ).readAsStringSync();

    expect(source, contains('authFlowType: AuthFlowType.pkce'));
    expect(source, contains('detectSessionInUri: true'));
  });

  test(
    'owner signup uses the current web origin for the confirmation callback',
    () {
      final source = File(
        'lib/features/owner/infrastructure/supabase_owner_repository.dart',
      ).readAsStringSync();

      expect(source, contains('emailRedirectTo: AppConfig.webAuthRedirectUri'));
    },
  );

  test('web redirect is derived from the initiating app origin', () {
    final source = File('lib/core/config/app_config.dart').readAsStringSync();

    expect(source, contains('WEB_AUTH_REDIRECT_URI'));
    expect(source, contains('Uri.base'));
  });

  test('email authentication uses Supabase six digit OTP APIs', () {
    final source = File(
      'lib/features/auth/infrastructure/supabase_auth_repository.dart',
    ).readAsStringSync();
    expect(source, contains('signInWithOtp(email: email)'));
    expect(source, contains('verifyOTP('));
    expect(source, contains('type: OtpType.email'));
  });

  test('confirmation template renders the Supabase token', () {
    final template = File(
      'supabase/templates/confirmation.html',
    ).readAsStringSync();
    expect(template, contains('{{ .Token }}'));
    expect(template, isNot(contains('{{ .ConfirmationURL }}')));
  });
}

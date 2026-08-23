import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner registration uses the shared email OTP flow', () {
    final source = File(
      'lib/features/owner/presentation/screens/owner_registration_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/owner/infrastructure/supabase_owner_repository.dart',
    ).readAsStringSync();

    expect(source, contains('requestOwnerOtp'));
    expect(source, contains('verifyOwnerOtp'));
    expect(repository, contains('signInWithOtp'));
    expect(repository, contains('verifyOTP'));
    expect(repository, contains('OtpType.email'));
  });
}

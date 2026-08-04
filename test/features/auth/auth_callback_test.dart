import 'package:bookmyspace/features/auth/domain/auth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes expired confirmation in callback query', () {
    final error = authCallbackErrorFromUri(
      Uri.parse(
        'http://127.0.0.1:4173/?error=access_denied&'
        'error_code=otp_expired&error_description=Email+link+is+expired#'
        '/auth/callback',
      ),
    );

    expect(error?.code, 'otp_expired');
    expect(error?.isExpired, isTrue);
  });

  test('recognizes callback errors placed after hash route', () {
    final error = authCallbackErrorFromUri(
      Uri.parse(
        'http://127.0.0.1:4173/#/auth/callback?'
        'error=access_denied&error_description=Link+has+expired',
      ),
    );

    expect(error?.code, 'access_denied');
    expect(error?.isExpired, isTrue);
  });

  test('recognizes successful PKCE callback at the site URL', () {
    expect(
      isAuthCallbackUri(Uri.parse('http://127.0.0.1:4173/?code=pkce-code')),
      isTrue,
    );
  });
}

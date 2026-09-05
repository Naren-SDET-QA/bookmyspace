import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' as app_errors;

/// Ensures a protected client request uses the real Supabase Auth session.
/// TEST_MODE role state is presentation-only and is never used as a token.
Future<Session> ensureSupabaseSession(SupabaseClient client) async {
  var session = client.auth.currentSession;
  if (hasUsableSupabaseSessionToken(session?.accessToken) &&
      !(session?.isExpired ?? true)) {
    return session!;
  }

  if (session != null) {
    try {
      session = (await client.auth.refreshSession()).session;
    } catch (_) {
      session = null;
    }
  }

  if ((!hasUsableSupabaseSessionToken(session?.accessToken) ||
          (session?.isExpired ?? true)) &&
      (AppConfig.isDevelopment ||
          AppConfig.environment == AppEnvironment.testing) &&
      AppConfig.devTestEmail.isNotEmpty &&
      AppConfig.devTestPassword.isNotEmpty) {
    await client.auth.signInWithPassword(
      email: AppConfig.devTestEmail,
      password: AppConfig.devTestPassword,
    );
    session = client.auth.currentSession;
  }

  if (!hasUsableSupabaseSessionToken(session?.accessToken) ||
      (session?.isExpired ?? true)) {
    throw const app_errors.AuthException(
      'You must be signed in with a valid DEV account to continue.',
      code: 'auth_session_required',
    );
  }
  return session!;
}

/// A shape check only; Supabase Auth remains responsible for JWT validation.
bool hasUsableSupabaseSessionToken(String? token) {
  if (token == null || token.isEmpty) return false;
  final parts = token.split('.');
  return parts.length == 3 && parts.every((part) => part.isNotEmpty);
}

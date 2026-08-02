import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' show AppException, mapError;
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart' as domain show AuthUser;

/// A Supabase authentication error surfaced to the presentation layer.
class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.code});
}

/// Supabase-backed [AuthRepository].
///
/// Session tokens are persisted by supabase_flutter in a secure backend
/// (FlutterSecureStorage under the hood on mobile).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  domain.AuthUser? get currentUser {
    final u = _client.auth.currentUser;
    if (u == null) return null;
    return _toUser(u);
  }

  @override
  Stream<domain.AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return _toUser(user);
    });
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AuthUser> verifyEmailOtp(String email, String token) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return _toUser(res.user!);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AuthUser> verifyPhoneOtp(String phone, String token) async {
    try {
      final res = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return _toUser(res.user!);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AuthUser> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? _webRedirect() : null,
      );
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('Google sign-in was not completed.');
      }
      return _toUser(user);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AuthUser> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? _webRedirect() : null,
      );
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('Apple sign-in was not completed.');
      }
      return _toUser(user);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signOutAllDevices() async {
    await signOut();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
      await _client.auth.signOut();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
    } catch (e) {
      throw mapError(e);
    }
  }

  domain.AuthUser _toUser(User u) {
    return domain.AuthUser(
      id: u.id,
      email: u.email ?? '',
      phone: u.phone ?? '',
      fullName: (u.userMetadata?['full_name'] ?? '') as String,
      avatarUrl: (u.userMetadata?['avatar_url'] ?? '') as String,
    );
  }

  String _webRedirect() {
    final url = Uri.parse(AppConfig.supabaseUrl);
    return '${url.scheme}://${url.host}';
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show AppException, mapError;
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart' as domain show AppAccessRole, AuthUser;

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
    return _client.auth.onAuthStateChange.asyncMap((data) async {
      final user = data.session?.user;
      if (user == null) return null;
      return _loadProfile(_toUser(user));
    });
  }

  Future<domain.AuthUser> _loadProfile(domain.AuthUser user) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, email, phone, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) return user;
      final profileEmail = (profile['email'] as String? ?? '').trim();
      return user.copyWith(
        fullName: (profile['full_name'] as String? ?? '').trim(),
        email: profileEmail.isNotEmpty ? profileEmail : user.email,
        phone: (profile['phone'] as String? ?? '').trim(),
        avatarUrl: (profile['avatar_url'] as String? ?? '').trim(),
      );
    } catch (_) {
      return user;
    }
  }

  @override
  Future<void> signInWithEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? webAuthCallbackUrl() : null,
      );
    } on AuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: kIsWeb ? webAuthCallbackUrl() : null,
      );
    } on AuthException catch (e) {
      throw _mapAuthError(e);
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
      throw _mapAuthError(e);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AuthUser> signInWithPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null || response.session == null) {
        throw const AppAuthException(
          'Development login did not create a session.',
        );
      }
      return _toUser(user);
    } on AuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<domain.AppAccessRole> resolveAccessRole() async {
    final value = await _client.rpc<String>('current_app_role');
    return switch (value) {
      'admin' => domain.AppAccessRole.admin,
      'owner' => domain.AppAccessRole.owner,
      _ => domain.AppAccessRole.customer,
    };
  }

  @override
  Future<void> signInWithPhoneOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw _mapAuthError(e);
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
      throw _mapAuthError(e);
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
      throw _mapAuthError(e);
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
      throw _mapAuthError(e);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuthError(e);
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
      throw _mapAuthError(e);
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

  String _webRedirect() => webAuthCallbackUrl();

  AppAuthException _mapAuthError(AuthException error) {
    final message = switch (error.code) {
      'otp_expired' =>
        'That code is expired or has already been used. Send a new code and try again.',
      'over_email_send_rate_limit' =>
        'Please wait a minute before requesting another code.',
      'validation_failed' =>
        'This sign-in method is not available. Use email OTP instead.',
      _ => error.message,
    };
    return AppAuthException(message, code: error.code);
  }
}

String webAuthCallbackUrl() => Uri.base.origin;

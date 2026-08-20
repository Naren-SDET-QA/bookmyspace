import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' show AppException, mapError;
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart' as domain;

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
    return _client.auth.onAuthStateChange.asyncExpand((data) async* {
      final user = data.session?.user;
      if (user == null) {
        yield null;
        return;
      }
      yield await _loadAuthoritativeUser(user);
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
  Future<domain.AuthUser> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final userMetadata = <String, dynamic>{};
      if (fullName != null) userMetadata['full_name'] = fullName;
      if (avatarUrl != null) userMetadata['avatar_url'] = avatarUrl;

      final res = await _client.auth.updateUser(
        UserAttributes(data: userMetadata),
      );

      final user = res.user ?? _client.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('Failed to update user profile.');
      }

      // Also sync to the public 'profiles' table if present in Supabase
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          if (fullName != null) 'full_name': fullName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Non-fatal if table/RLS policy is not configured yet
        debugPrint('Supabase profiles table upsert notice: $e');
      }

      return _toUser(user);
    } on AuthException catch (e) {
      throw AppAuthException(e.message);
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

  Future<domain.AuthUser> _loadAuthoritativeUser(User user) async {
    var profile = <String, dynamic>{};
    var role = domain.AppRole.customer;
    var verification = user.emailConfirmedAt != null
        ? domain.VerificationStatus.approved
        : domain.VerificationStatus.pending;
    try {
      final profileRow = await _client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      profile = profileRow ?? profile;
      final roleRows = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .isFilter('revoked_at', null);
      final roles = roleRows.map((row) => row['role'] as String? ?? '').toSet();
      if (roles.contains('administrator') ||
          roles.contains('super_administrator')) {
        role = domain.AppRole.admin;
        verification = domain.VerificationStatus.approved;
      } else if (roles.any(
        (value) =>
            value == 'venue_owner' ||
            value == 'institute_owner' ||
            value == 'event_organizer',
      )) {
        role = domain.AppRole.venueOwner;
        final owner = await _client
            .from('owner_profiles')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        if (owner != null) {
          final organization = await _client
              .from('organizations')
              .select('business_verification')
              .eq('owner_user_id', owner['id'])
              .maybeSingle();
          verification = domain.VerificationStatus.values.firstWhere(
            (status) => status.name == organization?['business_verification'],
            orElse: () => domain.VerificationStatus.pending,
          );
        }
      }
    } catch (_) {
      // Keep the authenticated user usable if optional profile hydration is
      // unavailable; protected screens still require the authoritative role.
    }
    return domain.AuthUser(
      id: user.id,
      email: user.email ?? '',
      phone: user.phone ?? '',
      fullName:
          profile['full_name'] as String? ??
          (user.userMetadata?['full_name'] as String? ?? ''),
      avatarUrl:
          profile['avatar_url'] as String? ??
          (user.userMetadata?['avatar_url'] as String? ?? ''),
      role: role,
      verificationStatus: verification,
    );
  }

  String _webRedirect() {
    final url = Uri.parse(AppConfig.supabaseUrl);
    return '${url.scheme}://${url.host}';
  }
}

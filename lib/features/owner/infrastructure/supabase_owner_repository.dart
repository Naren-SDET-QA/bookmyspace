import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/owner.dart';
import 'pending_owner_registration.dart';

/// Supabase-backed [OwnerRepository].
///
/// Owners are separate from user auth and have their own login flow.
class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(
    this._client, [
    PendingOwnerRegistrationStore? pending,
  ]) : _pending = pending ?? PendingOwnerRegistrationStore();

  final SupabaseClient _client;
  final PendingOwnerRegistrationStore _pending;

  static const String _ownerSelect = '''
    *,
    auth:auth_users(id, email, raw_user_meta_data)
  ''';

  @override
  Future<void> requestOwnerOtp(String email, String name) async {
    try {
      await _pending.save(email: email.trim(), name: name.trim());
      await _client.auth.signInWithOtp(email: email.trim());
    } on AuthException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Owner> verifyOwnerOtp({
    required String email,
    required String name,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
      if (response.user == null || _client.auth.currentSession == null) {
        throw const app_errors.AuthException(
          'Email verification did not create an authenticated session.',
        );
      }
      final ownerId = await _client.rpc<String>(
        'complete_owner_registration',
        params: {'p_name': name.trim()},
      );
      final ownerJson = await _client
          .from('owner_profiles')
          .select(_ownerSelect)
          .eq('id', ownerId)
          .single();
      await _pending.clear();
      return Owner.fromJson(ownerJson);
    } on AuthException catch (e) {
      throw app_errors.mapError(e);
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      await _pending.save(email: email, name: name);
      // Create auth user via sign_up
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
        emailRedirectTo: AppConfig.webAuthRedirectUri.isEmpty
            ? null
            : AppConfig.webAuthRedirectUri,
      );

      if (response.user == null) {
        throw const app_errors.AppError('Owner registration failed.');
      }

      // A signup can return a user without a session when email confirmation
      // is enabled. The role RPC requires an authenticated JWT, so establish
      // the session before invoking it and fail clearly if confirmation is
      // still required.
      final session = response.session ?? _client.auth.currentSession;
      if (session == null ||
          _client.auth.currentUser?.id != response.user!.id) {
        await _client.auth.signInWithPassword(email: email, password: password);
      }
      if (_client.auth.currentSession == null ||
          _client.auth.currentUser?.id != response.user!.id) {
        throw const app_errors.AuthException(
          'Owner signup requires a confirmed authenticated session.',
        );
      }

      final ownerId = await _client.rpc<String>(
        'complete_owner_registration',
        params: {'p_name': name},
      );

      final ownerJson = await _client
          .from('owner_profiles')
          .select(_ownerSelect)
          .eq('id', ownerId)
          .single();

      await _pending.clear();
      return Owner.fromJson(ownerJson);
    } on AuthException catch (e) {
      throw app_errors.mapError(e);
    } on PostgrestException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  /// Completes a signup that returned through the email-confirmation callback.
  /// The RPC remains the only server-side role/profile mutation.
  Future<void> completePendingOwnerRegistration() async {
    final pending = await _pending.read();
    final user = _client.auth.currentUser;
    if (pending == null || user == null || user.email != pending.email) return;

    final ownerId = await _client.rpc<String>(
      'complete_owner_registration',
      params: {'p_name': pending.name},
    );
    await _client
        .from('owner_profiles')
        .select('id')
        .eq('id', ownerId)
        .single();
    await _pending.clear();
  }

  @override
  Future<Owner?> currentOwner() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final row = await _client
          .from('owner_profiles')
          .select(_ownerSelect)
          .eq('user_id', userId)
          .maybeSingle();

      return row != null ? Owner.fromJson(row) : null;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<Owner> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const app_errors.AuthException('Invalid credentials.');
      }

      final ownerJson = await _client
          .from('owner_profiles')
          .select(_ownerSelect)
          .eq('user_id', response.user!.id)
          .single();

      return Owner.fromJson(ownerJson);
    } on AuthException catch (e) {
      throw app_errors.mapError(e);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const app_errors.AuthException('Owner account not found.');
      }
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> deleteOwner() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const app_errors.AuthException('No user signed in.');
      }

      await _client.rpc<void>(
        'delete_owner_account',
        params: {'p_user_id': user.id},
      );
    } on FunctionException catch (e) {
      throw app_errors.mapError(e);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

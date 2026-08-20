import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/owner.dart';

/// Supabase-backed [OwnerRepository].
///
/// Owners are separate from user auth and have their own login flow.
class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(this._client);

  final SupabaseClient _client;

  static const String _ownerSelect = '''
    *,
    auth:auth_users(id, email, raw_user_meta_data)
  ''';

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      // Create auth user via sign_up
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        throw const app_errors.AppError('Owner registration failed.');
      }

      final ownerJson = await _client
          .from('owner_profiles')
          .insert({'user_id': response.user!.id, 'email': email, 'name': name})
          .select(_ownerSelect)
          .single();

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

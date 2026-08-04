import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../../auth/infrastructure/supabase_auth_repository.dart';
import '../domain/owner.dart';

/// Supabase-backed [OwnerRepository].
///
/// Owners are separate from user auth and have their own login flow.
class SupabaseOwnerRepository implements OwnerRepository {
  SupabaseOwnerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Owner> createOwner({
    required String email,
    required String name,
    required String password,
  }) async {
    try {
      if (_client.auth.currentUser == null) {
        final response = await _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: webAuthCallbackUrl(),
          data: {'name': name, 'pending_role': 'owner'},
        );
        if (response.user == null || response.session == null) {
          throw const app_errors.AppError(
            'Confirm your email, sign in, then complete owner registration.',
          );
        }
      }

      final ownerJson = await _client.rpc<Map<String, dynamic>>(
        'save_owner_profile',
        params: {'p_name': name},
      );
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

      final row = await _client.rpc<dynamic>('get_owner_profile');
      return row is Map<String, dynamic> ? Owner.fromJson(row) : null;
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

      final ownerJson = await _client.rpc<dynamic>('get_owner_profile');
      if (ownerJson is! Map<String, dynamic>) {
        throw const app_errors.AuthException('Owner account not found.');
      }

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

  @override
  Future<Owner> saveProfile(Owner owner) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'save_owner_profile',
        params: {
          'p_name': owner.name,
          'p_phone': owner.phone,
          'p_whatsapp': owner.whatsapp,
          'p_business_name': owner.businessName,
          'p_address': owner.address,
          'p_city': owner.city,
          'p_state': owner.state,
          'p_latitude': owner.latitude,
          'p_longitude': owner.longitude,
          'p_photo_url': owner.photoUrl,
        },
      );
      return Owner.fromJson(json);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

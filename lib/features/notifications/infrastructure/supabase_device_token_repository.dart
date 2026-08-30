import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/device_token_repository.dart';

/// Supabase-backed [DeviceTokenRepository]. Tokens (OneSignal
/// push-subscription ids -- see OneSignalPushService) are stored in
/// `public.device_tokens`, one row per (user_id, token) pair, protected by
/// an owner-only RLS policy (mirroring `public.notifications`).
class SupabaseDeviceTokenRepository implements DeviceTokenRepository {
  SupabaseDeviceTokenRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> deregisterToken(String token) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _client
          .from('device_tokens')
          .delete()
          .eq('token', token)
          .eq('user_id', userId);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}

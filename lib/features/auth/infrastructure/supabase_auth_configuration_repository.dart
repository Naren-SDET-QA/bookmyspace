import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/auth_configuration.dart';
import '../domain/auth_configuration_repository.dart';

class SupabaseAuthConfigurationRepository
    implements AuthConfigurationRepository {
  SupabaseAuthConfigurationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AuthConfiguration> load() async {
    try {
      final row = await _client
          .from('module_feature_configs')
          .select('metadata')
          .eq('module_key', 'auth')
          .isFilter('venue_id', null)
          .maybeSingle();
      return AuthConfiguration.fromJson(row?['metadata']);
    } catch (_) {
      return const AuthConfiguration();
    }
  }

  @override
  Future<void> update(Map<String, bool> flags) async {
    final row = await _client
        .from('module_feature_configs')
        .select('id, metadata')
        .eq('module_key', 'auth')
        .isFilter('venue_id', null)
        .maybeSingle();
    final normalized = Map<String, bool>.from(flags);
    if (normalized['authentication_enabled'] == false) {
      for (final key in _providerKeys) normalized[key] = false;
    }
    if (normalized['phone_login_enabled'] == false) {
      normalized['phone_otp_enabled'] = false;
    }
    if (normalized['email_login_enabled'] == false) {
      normalized['email_otp_enabled'] = false;
      normalized['password_login_enabled'] = false;
    }
    final metadata = Map<String, dynamic>.from(
      (row?['metadata'] as Map?) ?? const <String, dynamic>{},
    )..addAll(normalized);
    if (row == null) {
      await _client.from('module_feature_configs').insert({
        'module_key': 'auth',
        'metadata': metadata,
      });
    } else {
      await _client
          .from('module_feature_configs')
          .update({'metadata': metadata})
          .eq('id', row['id'] as Object);
    }
  }

  static const _providerKeys = [
    'signup_enabled',
    'phone_login_enabled',
    'phone_otp_enabled',
    'email_login_enabled',
    'email_otp_enabled',
    'password_login_enabled',
    'google_login_enabled',
    'apple_login_enabled',
  ];
}

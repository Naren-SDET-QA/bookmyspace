import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/registration_field_config.dart';

class SupabaseRegistrationConfigRepository {
  SupabaseRegistrationConfigRepository(this._client);
  final SupabaseClient _client;

  Future<List<RegistrationFieldConfig>> ownerFields() async {
    final rows = await _client
        .from('owner_registration_field_configs')
        .select('*')
        .eq('enabled', true)
        .eq('owner_visible', true)
        .order('display_order');
    return rows.map(RegistrationFieldConfig.fromJson).toList();
  }

  Future<List<RegistrationFieldConfig>> allFields() async {
    final rows = await _client
        .from('owner_registration_field_configs')
        .select('*')
        .order('display_order');
    return rows.map(RegistrationFieldConfig.fromJson).toList();
  }

  Future<void> saveOwnerValues(Map<String, String> values) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    await _client.from('owner_registration_values').upsert([
      for (final entry in values.entries)
        {
          'owner_user_id': userId,
          'field_key': entry.key,
          'value_text': entry.value,
        },
    ], onConflict: 'owner_user_id,field_key');
  }

  Future<void> updateFieldConfig(
    String fieldKey,
    Map<String, dynamic> changes,
  ) async {
    await _client
        .from('owner_registration_field_configs')
        .update(changes)
        .eq('field_key', fieldKey);
  }
}

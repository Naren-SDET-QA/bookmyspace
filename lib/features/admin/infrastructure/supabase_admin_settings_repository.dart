import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/admin_settings.dart';

class SupabaseAdminSettingsRepository {
  SupabaseAdminSettingsRepository(this.client);
  final SupabaseClient client;

  Future<AdminSettings> load() async {
    final rows = await client
        .from('module_feature_configs')
        .select('module_key,metadata')
        .isFilter('venue_id', null);
    final maps = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = row['module_key']?.toString();
      final metadata = row['metadata'];
      if (key != null && metadata is Map)
        maps[key] = Map<String, dynamic>.from(metadata);
    }
    return AdminSettings(
      home: {...AdminSettings.defaults.home, ...?maps['home_ui']},
      theme: {...AdminSettings.defaults.theme, ...?maps['theme']},
      modules: maps['modules'] ?? const {},
    );
  }

  Future<void> saveSection(String section, Map<String, dynamic> values) async {
    final existing = await client
        .from('module_feature_configs')
        .select('id,metadata')
        .eq('module_key', section)
        .isFilter('venue_id', null)
        .maybeSingle();
    if (existing == null) {
      await client.from('module_feature_configs').insert({
        'module_key': section,
        'metadata': values,
      });
    } else {
      await client
          .from('module_feature_configs')
          .update({'metadata': values})
          .eq('id', existing['id'] as Object);
    }
  }
}

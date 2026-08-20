import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/module_registration.dart';
import '../domain/module_registration_repository.dart';

class SupabaseModuleRegistrationRepository
    implements ModuleRegistrationRepository {
  SupabaseModuleRegistrationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ModuleFeatureConfig?> featureConfig(
    String moduleKey, {
    String? venueId,
  }) async {
    final query = _client
        .from('module_feature_configs')
        .select()
        .eq('module_key', moduleKey);
    final rows = await query
        .or(
          venueId == null
              ? 'venue_id.is.null'
              : 'venue_id.eq.$venueId,venue_id.is.null',
        )
        .order('venue_id', ascending: false)
        .limit(1);
    return rows.isEmpty
        ? null
        : ModuleFeatureConfig.fromJson(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<List<ModuleFormVersion>> publishedForms(
    String moduleKey, {
    String? venueId,
  }) async {
    final rows = await _client
        .from('module_form_versions')
        .select()
        .eq('module_key', moduleKey)
        .eq('status', 'published')
        .or(
          venueId == null
              ? 'venue_id.is.null'
              : 'venue_id.eq.$venueId,venue_id.is.null',
        )
        .order('version', ascending: false);
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      final rawFields = json['fields'] is List
          ? json['fields'] as List
          : const [];
      return ModuleFormVersion(
        id: json['id'] as String? ?? '',
        moduleKey: moduleKey,
        version: (json['version'] as num?)?.toInt() ?? 0,
        fields: rawFields
            .whereType<Map>()
            .map(
              (field) => ModuleFormField(
                key: field['key'] as String? ?? '',
                label: field['label'] as String? ?? '',
                type: ModuleFieldType.values.firstWhere(
                  (t) => t.name == field['type'],
                  orElse: () => ModuleFieldType.text,
                ),
                required: field['required'] as bool? ?? false,
                enabled: field['enabled'] as bool? ?? true,
                options: (field['options'] as List? ?? const [])
                    .whereType<String>()
                    .toList(),
              ),
            )
            .toList(),
      );
    }).toList();
  }

  Future<List<ModuleDocumentRequirement>> documentRequirements(
    String moduleKey, {
    String? venueId,
  }) async {
    final rows = await _client
        .from('module_document_requirements')
        .select()
        .eq('module_key', moduleKey)
        .eq('enabled', true)
        .or(
          venueId == null
              ? 'venue_id.is.null'
              : 'venue_id.eq.$venueId,venue_id.is.null',
        )
        .order('sort_order');
    return rows
        .map(
          (row) => ModuleDocumentRequirement.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  @override
  Future<String> submit({
    required String moduleKey,
    String? venueId,
    String? bookingId,
    required String formVersionId,
    required Map<String, dynamic> values,
    required String idempotencyKey,
  }) async {
    final result = await _client.rpc<List<dynamic>>(
      'submit_module_registration',
      params: {
        'p_module_key': moduleKey,
        'p_venue_id': venueId,
        'p_booking_id': bookingId,
        'p_form_version_id': formVersionId,
        'p_values': values,
        'p_idempotency_key': idempotencyKey,
      },
    );
    Map<String, dynamic>? row;
    for (final item in result) {
      if (item is Map<String, dynamic>) {
        row = item;
        break;
      }
    }
    if (row == null || row['submission_id'] is! String) {
      throw StateError('Registration submission returned no id');
    }
    return row['submission_id'] as String;
  }
}

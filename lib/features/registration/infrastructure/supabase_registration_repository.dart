import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exceptions.dart' as errors;
import '../domain/registration_form.dart';

class SupabaseRegistrationRepository implements RegistrationRepository {
  SupabaseRegistrationRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<RegistrationFormDefinition>> myForms() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const [];
      final templates = await client
          .from('registration_form_templates')
          .select()
          .eq('owner_user_id', uid)
          .order('updated_at', ascending: false);
      final result = <RegistrationFormDefinition>[];
      for (final t in templates) {
        result.add(await form(t['id'] as String));
      }
      return result;
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<RegistrationFormDefinition> form(String id) async {
    try {
      final t = await client
          .from('registration_form_templates')
          .select()
          .eq('id', id)
          .single();
      final v = await client
          .from('registration_form_versions')
          .select()
          .eq('template_id', id)
          .eq('version', t['current_version'] as Object)
          .single();
      return RegistrationFormDefinition.fromJson(t, v);
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<String> create(
    String name,
    String moduleKey,
    List<RegistrationFieldDefinition> fields,
  ) async {
    try {
      return await client.rpc<String>(
        'create_registration_form',
        params: {
          'p_name': name,
          'p_module_key': moduleKey,
          'p_schema': {'fields': fields.map((e) => e.toJson()).toList()},
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<int> save(RegistrationFormDefinition form) async {
    try {
      return await client.rpc<int>(
        'save_registration_form_version',
        params: {'p_template_id': form.id, 'p_schema': form.schemaJson()},
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> publish(String id) async {
    try {
      await client.rpc<void>(
        'publish_registration_form',
        params: {'p_template_id': id},
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> bind(
    String id,
    String moduleKey,
    String? resourceId,
    String stage,
  ) async {
    try {
      await client.rpc<String>(
        'bind_registration_form',
        params: {
          'p_template_id': id,
          'p_module_key': moduleKey,
          'p_resource_id': resourceId,
          'p_collection_stage': stage,
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<String> submit(
    String id,
    String? bookingId,
    Map<String, dynamic> payload, {
    int participantIndex = 0,
    String participantScope = 'primary',
    String stage = 'pre_booking',
  }) async {
    try {
      return await client.rpc<String>(
        'submit_registration_form',
        params: {
          'p_template_id': id,
          'p_booking_id': bookingId,
          'p_payload': payload,
          'p_participant_index': participantIndex,
          'p_participant_scope': participantScope,
          'p_collection_stage': stage,
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }

  @override
  Future<void> upload(
    String submissionId,
    String fieldKey,
    String name,
    String mimeType,
    List<int> bytes,
  ) async {
    try {
      final uid = client.auth.currentUser!.id;
      final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          '$uid/$submissionId/${DateTime.now().microsecondsSinceEpoch}_$safe';
      await client.storage
          .from('registration-documents')
          .uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
      await client.rpc<String>(
        'attach_registration_file',
        params: {
          'p_submission_id': submissionId,
          'p_field_key': fieldKey,
          'p_storage_path': path,
          'p_original_name': name,
          'p_mime_type': mimeType,
          'p_size_bytes': bytes.length,
        },
      );
    } catch (e) {
      throw errors.mapError(e);
    }
  }
}

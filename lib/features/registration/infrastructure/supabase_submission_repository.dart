import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/module_submission.dart';

class SupabaseSubmissionRepository {
  SupabaseSubmissionRepository(this.client);
  final SupabaseClient client;

  Future<ModuleSubmission> byId(String id) async {
    final row = await client
        .from('module_form_submissions')
        .select()
        .eq('id', id)
        .single();
    return ModuleSubmission.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String> uploadDocument({
    required String submissionId,
    required String requirementId,
    required String userId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final path = '$userId/$submissionId/$requirementId-$filename';
    await client.storage
        .from('module-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    await client.rpc<dynamic>(
      'register_module_submission_document',
      params: {
        'p_submission_id': submissionId,
        'p_requirement_id': requirementId,
        'p_storage_path': path,
        'p_mime_type': mimeType,
        'p_size_bytes': bytes.length,
      },
    );
    return path;
  }

  Future<String> signedDocumentUrl(
    String path, {
    Duration expiresIn = const Duration(minutes: 10),
  }) => client.storage
      .from('module-documents')
      .createSignedUrl(path, expiresIn.inSeconds);

  Future<void> retryUpload({
    required String submissionId,
    required String requirementId,
    required String userId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) => uploadDocument(
    submissionId: submissionId,
    requirementId: requirementId,
    userId: userId,
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
  );

  Future<ModuleSubmission> review(
    String id,
    String status, {
    String? reason,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'review_module_submission',
      params: {
        'p_submission_id': id,
        'p_next_status': status,
        'p_reason': reason,
      },
    );
    final row = rows.whereType<Map<String, dynamic>>().first;
    return ModuleSubmission.fromJson(row);
  }
}

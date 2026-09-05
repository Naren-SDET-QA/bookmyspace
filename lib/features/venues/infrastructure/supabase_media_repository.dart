import 'dart:typed_data';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/media_item.dart';
import '../domain/media_repository.dart';
import '../domain/media_resilience.dart';
import 'transient_network_error.dart';

/// Generic owner media operations. Authorization remains in Supabase RLS;
/// this repository never uses a service-role key and never decides ownership.
class SupabaseMediaRepository implements MediaRepository {
  SupabaseMediaRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, venue_id, url, thumbnail_url, alt_text, is_cover, sort_order, '
      'media_kind, is_active, title, description, content_type, size_bytes, '
      'processing_status, upload_key';

  @override
  Future<MediaItem> upload({
    required String venueId,
    required MediaKind kind,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in as the owner to upload media.');
    }
    MediaUploadValidation.validate(
      kind: kind,
      contentType: contentType,
      fileName: fileName,
      sizeBytes: bytes.length,
    );
    final uploadKey = _uploadKey(venueId, kind, fileName, bytes);
    try {
      final existing = await _client
          .from('venue_images')
          .select(_columns)
          .eq('venue_id', venueId)
          .eq('upload_key', uploadKey)
          .maybeSingle();
      if (existing != null) return MediaItem.fromJson(existing);
    } catch (error) {
      throw mapError(error);
    }
    return const MediaRetryPolicy().run<MediaItem>(
      operation: (_) async {
        try {
          final folder = switch (kind) {
            MediaKind.image => 'images',
            MediaKind.video => 'videos',
            MediaKind.model3d => 'models_3d',
          };
          final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final path =
              '$uid/$venueId/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
          await _client.storage
              .from('venue-images')
              .uploadBinary(
                path,
                Uint8List.fromList(bytes),
                fileOptions: FileOptions(
                  contentType: contentType,
                  upsert: false,
                ),
              );
          final url = _client.storage.from('venue-images').getPublicUrl(path);
          final row = await _client
              .from('venue_images')
              .insert({
                'venue_id': venueId,
                'url': url,
                'media_kind': switch (kind) {
                  MediaKind.image => 'image',
                  MediaKind.video => 'video',
                  MediaKind.model3d => 'model_3d',
                },
                'content_type': contentType,
                'size_bytes': bytes.length,
                'processing_status': 'ready',
                'is_active': true,
                'upload_key': uploadKey,
              })
              .select(_columns)
              .single();
          return MediaItem.fromJson(row);
        } catch (error) {
          if (error is MediaFailure) rethrow;
          if (error is PostgrestException && error.code == '42501') {
            throw const MediaFailure(MediaFailureKind.unauthorized);
          }
          final text = error.toString().toLowerCase();
          if (error is TimeoutException ||
              isTransientNetworkError(error) ||
              (text.contains('storage') &&
                  !text.contains('401') &&
                  !text.contains('403'))) {
            throw const MediaFailure(MediaFailureKind.transient);
          }
          rethrow;
        }
      },
      wait: (_) async {},
    );
  }

  @override
  Future<List<MediaItem>> listForVenue(String venueId) async {
    try {
      final rows = await _client
          .from('venue_images')
          .select(_columns)
          .eq('venue_id', venueId)
          .order('sort_order');
      return rows.map(MediaItem.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<MediaItem> update(MediaItem media) async {
    try {
      final row = await _client
          .from('venue_images')
          .update({
            'url': media.url,
            'thumbnail_url': media.thumbnailUrl,
            'title': media.title,
            'description': media.description,
            'is_active': media.isActive,
            'is_cover': media.isCover,
            'sort_order': media.sortOrder,
            'media_kind': _kindValue(media.kind),
            'processing_status': _statusValue(media.processingStatus),
          })
          .eq('id', media.id)
          .select(_columns)
          .single();
      return MediaItem.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> delete(String mediaId) async {
    try {
      await _client.from('venue_images').delete().eq('id', mediaId);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> reorder(String venueId, List<String> orderedMediaIds) async {
    for (var index = 0; index < orderedMediaIds.length; index++) {
      await _client
          .from('venue_images')
          .update({'sort_order': index, 'is_cover': index == 0})
          .eq('venue_id', venueId)
          .eq('id', orderedMediaIds[index]);
    }
  }

  String _kindValue(MediaKind kind) => switch (kind) {
    MediaKind.image => 'image',
    MediaKind.video => 'video',
    MediaKind.model3d => 'model_3d',
  };

  String _statusValue(MediaProcessingStatus status) => switch (status) {
    MediaProcessingStatus.pending => 'pending',
    MediaProcessingStatus.processing => 'processing',
    MediaProcessingStatus.uploading => 'uploading',
    MediaProcessingStatus.ready => 'ready',
    MediaProcessingStatus.failed => 'failed',
  };

  String _uploadKey(
    String venueId,
    MediaKind kind,
    String fileName,
    List<int> bytes,
  ) {
    // Keep the deterministic upload key stable across Dart VM and JavaScript.
    // JavaScript cannot represent the 64-bit FNV-1a constants exactly.
    var hash = 2166136261;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return '${venueId}_${kind.name}_${fileName.toLowerCase()}_${bytes.length}_$hash';
  }
}

enum MediaKind { image, video, model3d }

enum MediaProcessingStatus { pending, uploading, processing, ready, failed }

class MediaUploadValidation {
  static const imageMaxBytes = 5 * 1024 * 1024;
  static const videoMaxBytes = 50 * 1024 * 1024;
  static const model3dMaxBytes = 50 * 1024 * 1024;

  static const imageTypes = {'image/jpeg', 'image/png', 'image/webp'};
  static const videoTypes = {'video/mp4', 'video/webm', 'video/quicktime'};
  static const model3dTypes = {
    'model/gltf-binary',
    'model/gltf+json',
    'application/octet-stream',
  };

  static void validate({
    required MediaKind kind,
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) {
    if (sizeBytes <= 0) throw StateError('The selected file is empty.');
    final allowed = switch (kind) {
      MediaKind.image => imageTypes,
      MediaKind.video => videoTypes,
      MediaKind.model3d => model3dTypes,
    };
    if (!allowed.contains(contentType.toLowerCase())) {
      throw StateError('This file type is not supported.');
    }
    final extension = fileName.toLowerCase().split('.').last;
    final extensions = switch (kind) {
      MediaKind.image => {'jpg', 'jpeg', 'png', 'webp'},
      MediaKind.video => {'mp4', 'webm', 'mov'},
      MediaKind.model3d => {'glb', 'gltf'},
    };
    if (!extensions.contains(extension)) {
      throw StateError('This file extension is not supported.');
    }
    final max = switch (kind) {
      MediaKind.image => imageMaxBytes,
      MediaKind.video => videoMaxBytes,
      MediaKind.model3d => model3dMaxBytes,
    };
    if (sizeBytes > max) throw StateError('The selected file is too large.');
  }
}

/// Generic `venue_images` media row. Unknown values fail closed so a new
/// provider or media type cannot become visible accidentally.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.venueId,
    required this.url,
    required this.kind,
    required this.isActive,
    required this.isCover,
    required this.sortOrder,
    required this.processingStatus,
    this.thumbnailUrl = '',
    this.title = '',
    this.description = '',
    this.contentType = '',
    this.sizeBytes,
    this.uploadKey = '',
  });

  final String id;
  final String venueId;
  final String url;
  final MediaKind kind;
  final bool isActive;
  final bool isCover;
  final int sortOrder;
  final MediaProcessingStatus processingStatus;
  final String thumbnailUrl;
  final String title;
  final String description;
  final String contentType;
  final int? sizeBytes;
  final String uploadKey;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    MediaKind parseKind(Object? raw) => switch (raw) {
      'video' => MediaKind.video,
      'model_3d' => MediaKind.model3d,
      'image' => MediaKind.image,
      _ => MediaKind.image,
    };

    MediaProcessingStatus parseStatus(Object? raw) => switch (raw) {
      'pending' => MediaProcessingStatus.pending,
      'processing' => MediaProcessingStatus.processing,
      'uploading' => MediaProcessingStatus.uploading,
      'ready' => MediaProcessingStatus.ready,
      'failed' => MediaProcessingStatus.failed,
      _ => MediaProcessingStatus.failed,
    };

    return MediaItem(
      id: json['id'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      kind: parseKind(json['media_kind']),
      isActive: json['is_active'] as bool? ?? false,
      isCover: json['is_cover'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      processingStatus: parseStatus(json['processing_status']),
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      uploadKey: json['upload_key'] as String? ?? '',
    );
  }
}

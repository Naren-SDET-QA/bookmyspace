import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/venues/domain/media_item.dart';

void main() {
  test('parses generic media metadata and preserves media kind', () {
    final media = MediaItem.fromJson({
      'id': 'm1',
      'venue_id': 'v1',
      'url': 'https://cdn.example/m1.glb',
      'media_kind': 'model_3d',
      'is_active': true,
      'is_cover': false,
      'sort_order': 2,
      'processing_status': 'ready',
      'size_bytes': 42,
    });

    expect(media.id, 'm1');
    expect(media.kind, MediaKind.model3d);
    expect(media.isActive, isTrue);
    expect(media.processingStatus, MediaProcessingStatus.ready);
    expect(media.sizeBytes, 42);
  });

  test('unknown values fail closed to safe defaults', () {
    final media = MediaItem.fromJson({
      'id': 'm2',
      'url': 'https://cdn.example/unknown',
      'media_kind': 'audio',
      'processing_status': 'unknown',
    });

    expect(media.kind, MediaKind.image);
    expect(media.processingStatus, MediaProcessingStatus.failed);
    expect(media.isActive, isFalse);
  });

  test('validates video and 3D upload type and size', () {
    expect(
      () => MediaUploadValidation.validate(
        kind: MediaKind.video,
        contentType: 'video/mp4',
        fileName: 'tour.mp4',
        sizeBytes: 100,
      ),
      returnsNormally,
    );
    expect(
      () => MediaUploadValidation.validate(
        kind: MediaKind.model3d,
        contentType: 'model/gltf-binary',
        fileName: 'room.glb',
        sizeBytes: 100,
      ),
      returnsNormally,
    );
    expect(
      () => MediaUploadValidation.validate(
        kind: MediaKind.image,
        contentType: 'image/png',
        fileName: 'large.png',
        sizeBytes: MediaUploadValidation.imageMaxBytes + 1,
      ),
      throwsStateError,
    );
  });
}

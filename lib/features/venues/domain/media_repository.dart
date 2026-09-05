import 'media_item.dart';

abstract interface class MediaRepository {
  Future<MediaItem> upload({
    required String venueId,
    required MediaKind kind,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  Future<List<MediaItem>> listForVenue(String venueId);

  Future<MediaItem> update(MediaItem media);

  Future<void> delete(String mediaId);

  Future<void> reorder(String venueId, List<String> orderedMediaIds);
}

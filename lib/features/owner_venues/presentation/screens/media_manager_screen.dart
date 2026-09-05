import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/domain/media_item.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../providers/owner_venue_providers.dart';
import '../widgets/media_preview.dart';

final mediaForVenueProvider = FutureProvider.autoDispose
    .family<List<MediaItem>, String>((ref, venueId) {
      return ref.watch(mediaRepositoryProvider).listForVenue(venueId);
    });

/// One category-neutral owner media manager. It intentionally delegates all
/// authorization to RLS and accepts only a venue id plus DB-backed config.
class MediaManagerScreen extends ConsumerWidget {
  const MediaManagerScreen({required this.venueId, super.key});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueState = ref.watch(myVenuesProvider);
    final mediaState = ref.watch(mediaForVenueProvider(venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Media')),
      body: venueState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load listing.')),
        data: (venues) {
          final venue = venues.cast<Venue?>().firstWhere(
            (item) => item?.id == venueId,
            orElse: () => null,
          );
          if (venue == null)
            return const Center(child: Text('Listing not found.'));
          final config = venue.category == null
              ? null
              : CategoryConfiguration.fromCategory(venue.category!);
          return _MediaBody(
            venueId: venueId,
            config: config,
            mediaState: mediaState,
            onRefresh: () => ref.invalidate(mediaForVenueProvider(venueId)),
          );
        },
      ),
    );
  }
}

class _MediaBody extends ConsumerWidget {
  const _MediaBody({
    required this.venueId,
    required this.config,
    required this.mediaState,
    required this.onRefresh,
  });

  final String venueId;
  final CategoryConfiguration? config;
  final AsyncValue<List<MediaItem>> mediaState;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = config?.mediaEnabled ?? false;
    if (!enabled) {
      return const Center(child: Text('Media is disabled for this category.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Manage listing media',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (config?.ownerUploadEnabled == true)
                PopupMenuButton<MediaKind>(
                  tooltip: 'Add media',
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  onSelected: (kind) => _pickAndUpload(context, ref, kind),
                  itemBuilder: (context) => [
                    if (config?.imagesEnabled == true)
                      const PopupMenuItem(
                        value: MediaKind.image,
                        child: Text('Add photo'),
                      ),
                    if (config?.videosEnabled == true)
                      const PopupMenuItem(
                        value: MediaKind.video,
                        child: Text('Add video'),
                      ),
                    if (config?.models3dEnabled == true)
                      const PopupMenuItem(
                        value: MediaKind.model3d,
                        child: Text('Add 3D model'),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: mediaState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Unable to load media.')),
            data: (items) => items.isEmpty
                ? const Center(child: Text('No media yet.'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;
                      final ordered = [...items];
                      final moved = ordered.removeAt(oldIndex);
                      ordered.insert(newIndex, moved);
                      await ref
                          .read(mediaRepositoryProvider)
                          .reorder(
                            venueId,
                            ordered.map((item) => item.id).toList(),
                          );
                      onRefresh();
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        key: ValueKey(item.id),
                        child: ListTile(
                          leading: item.kind == MediaKind.image
                              ? AppNetworkImage(
                                  url: item.url,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : CircleAvatar(child: Icon(_icon(item.kind))),
                          title: Text(
                            item.title.isEmpty ? _label(item.kind) : item.title,
                          ),
                          subtitle: Text(
                            '${item.isActive ? 'Enabled' : 'Disabled'} · ${item.processingStatus.name}',
                          ),
                          onTap: item.kind == MediaKind.image
                              ? null
                              : () => showMediaPreview(context, item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.kind != MediaKind.image)
                                IconButton(
                                  tooltip: 'Preview',
                                  icon: const Icon(Icons.play_circle_outline),
                                  onPressed: () =>
                                      showMediaPreview(context, item),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'delete') {
                                    await ref
                                        .read(mediaRepositoryProvider)
                                        .delete(item.id);
                                  } else {
                                    await ref
                                        .read(mediaRepositoryProvider)
                                        .update(
                                          MediaItem(
                                            id: item.id,
                                            venueId: item.venueId,
                                            url: item.url,
                                            kind: item.kind,
                                            isActive: action == 'toggle'
                                                ? !item.isActive
                                                : item.isActive,
                                            isCover: action == 'cover'
                                                ? true
                                                : item.isCover,
                                            sortOrder: item.sortOrder,
                                            processingStatus:
                                                item.processingStatus,
                                            thumbnailUrl: item.thumbnailUrl,
                                            title: item.title,
                                            description: item.description,
                                            contentType: item.contentType,
                                            sizeBytes: item.sizeBytes,
                                          ),
                                        );
                                  }
                                  onRefresh();
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'toggle',
                                    child: Text('Enable/Disable'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'cover',
                                    child: Text('Set cover'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(
    BuildContext context,
    WidgetRef ref,
    MediaKind kind,
  ) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result.isEmpty) return;
    final file = result.first;
    final bytes = await file.readAsBytes();
    final contentType = _contentType(file.extension ?? '', kind);
    try {
      await ref
          .read(mediaRepositoryProvider)
          .upload(
            venueId: venueId,
            kind: kind,
            bytes: bytes,
            fileName: file.name,
            contentType: contentType,
          );
      onRefresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media upload failed. Check type and size.'),
          ),
        );
      }
    }
  }

  String _contentType(String extension, MediaKind kind) {
    final ext = extension.toLowerCase();
    return switch (kind) {
      MediaKind.image => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/png',
      },
      MediaKind.video => switch (ext) {
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        _ => 'video/mp4',
      },
      MediaKind.model3d =>
        ext == 'gltf' ? 'model/gltf+json' : 'model/gltf-binary',
    };
  }

  static IconData _icon(MediaKind kind) => switch (kind) {
    MediaKind.image => Icons.image,
    MediaKind.video => Icons.videocam,
    MediaKind.model3d => Icons.view_in_ar,
  };

  static String _label(MediaKind kind) => switch (kind) {
    MediaKind.image => 'Image',
    MediaKind.video => 'Video',
    MediaKind.model3d => '3D model',
  };
}

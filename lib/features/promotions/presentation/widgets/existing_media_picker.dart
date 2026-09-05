import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../venues/domain/media_item.dart';
import '../../../venues/presentation/venue_providers.dart';

class ExistingMediaPicker extends ConsumerWidget {
  const ExistingMediaPicker({
    required this.venueIds,
    required this.selectedId,
    required this.onSelected,
    required this.onRemoved,
    super.key,
  });

  final List<String> venueIds;
  final String? selectedId;
  final ValueChanged<MediaItem> onSelected;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (venueIds.isEmpty) {
      return const ListTile(
        title: Text('Select a venue to choose its banner media.'),
      );
    }
    return FutureBuilder<List<MediaItem>>(
      future:
          Future.wait([
            for (final id in venueIds)
              ref.read(mediaRepositoryProvider).listForVenue(id),
          ]).then(
            (lists) => lists
                .expand((items) => items)
                .where(
                  (item) =>
                      item.kind == MediaKind.image &&
                      item.isActive &&
                      item.processingStatus == MediaProcessingStatus.ready &&
                      Uri.tryParse(item.url)?.hasAbsolutePath == true,
                )
                .toList(),
          ),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <MediaItem>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          children: [
            for (final media in items)
              RadioListTile<String>(
                value: media.id,
                groupValue: selectedId,
                onChanged: (_) => onSelected(media),
                title: Text(media.title.isEmpty ? 'Image' : media.title),
                secondary: Image.network(
                  media.thumbnailUrl.isEmpty ? media.url : media.thumbnailUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            if (selectedId != null)
              TextButton.icon(
                onPressed: onRemoved,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove banner'),
              ),
          ],
        );
      },
    );
  }
}

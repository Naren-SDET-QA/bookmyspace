import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/review.dart';
import '../providers/review_providers.dart';

/// Widget showing venue reviews with an option to add a review.
class VenueReviewsSection extends ConsumerWidget {
  const VenueReviewsSection({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reviews = ref.watch(venueReviewsProvider(venueId));
    final myReview = ref.watch(myReviewProvider(venueId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.reviews,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (myReview.valueOrNull == null)
              TextButton.icon(
                onPressed: () => _showReviewDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Review'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.reviews_rounded,
                  title: 'No reviews yet',
                  message: 'Be the first to review this venue.',
                )
              : Column(
                  children: items.map((r) => _ReviewTile(review: r)).toList(),
                ),
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int rating = 5;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog<AlertDialog>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Write a Review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return IconButton(
                      icon: Icon(
                        star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppTheme.accent,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = star),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Your review',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await ref.read(submitReviewProvider((
                  venueId: venueId,
                  rating: rating,
                  title: titleController.text.trim().isEmpty
                      ? null
                      : titleController.text.trim(),
                  body: bodyController.text.trim().isEmpty
                      ? null
                      : bodyController.text.trim(),
                )).future);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: AppTheme.accent,
                  );
                }),
                const SizedBox(width: 8),
                if (review.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Verified',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review.title!,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            if (review.body != null && review.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                review.body!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (review.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../domain/review.dart';
import '../providers/review_providers.dart';

/// Widget showing venue reviews with an option to add a review.
class VenueReviewsSection extends ConsumerStatefulWidget {
  const VenueReviewsSection({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<VenueReviewsSection> createState() =>
      _VenueReviewsSectionState();
}

class _VenueReviewsSectionState extends ConsumerState<VenueReviewsSection> {
  int? _selectedStar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reviews = ref.watch(venueReviewsProvider(widget.venueId));
    final myReview = ref.watch(myReviewProvider(widget.venueId));
    final bookings = ref.watch(myBookingsProvider);
    final eligibleBookings =
        bookings.valueOrNull
            ?.where(
              (booking) =>
                  booking.venueId == widget.venueId &&
                  (booking.status == BookingStatus.confirmed ||
                      booking.status == BookingStatus.completed ||
                      booking.status == BookingStatus.held ||
                      booking.paidAt != null ||
                      booking.paymentRef.isNotEmpty),
            )
            .toList() ??
        const <Booking>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.reviews,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (myReview.valueOrNull == null)
              TextButton.icon(
                onPressed: () => _showReviewDialog(context, eligibleBookings),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Review'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
          data: (items) {
            final filtered = Review.filterByStar(items, _selectedStar);
            return Column(
              children: [
                if (items.isNotEmpty)
                  _StarFilters(
                    selected: _selectedStar,
                    reviews: items,
                    onSelected: (star) => setState(() {
                      _selectedStar = _selectedStar == star ? null : star;
                    }),
                  ),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.reviews_rounded,
                    title: _selectedStar == null
                        ? 'No reviews yet'
                        : 'No $_selectedStar★ reviews found',
                    message: _selectedStar == null
                        ? 'Be the first to review this venue.'
                        : 'Try another rating filter.',
                  )
                else
                  ...filtered.map((r) => _ReviewTile(review: r)),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context, List<Booking> bookings) {
    int rating = 5;
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String? bookingId;
    final selectedTags = <String>{};
    const availableTags = [
      'Clean Courts',
      'Great Lighting',
      'Easy Parking',
      'Helpful Staff',
      'Good Value',
      'Well Maintained',
      'Quality Turf',
      'Top Equipment',
    ];

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
                        star <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
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
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Highlights (optional)',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setTagState) => Wrap(
                    spacing: 6,
                    children: availableTags
                        .map(
                          (tag) => FilterChip(
                            label: Text(tag),
                            selected: selectedTags.contains(tag),
                            onSelected: (selected) => setTagState(() {
                              selected
                                  ? selectedTags.add(tag)
                                  : selectedTags.remove(tag);
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (bookings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: bookingId,
                    decoration: const InputDecoration(
                      labelText: 'Booking (optional)',
                    ),
                    items: bookings
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.bookingRef),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => bookingId = value,
                  ),
                ],
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
                await ref.read(
                  submitReviewProvider((
                    venueId: widget.venueId,
                    rating: rating,
                    title: titleController.text.trim().isEmpty
                        ? null
                        : titleController.text.trim(),
                    body: bodyController.text.trim().isEmpty
                        ? null
                        : bodyController.text.trim(),
                    bookingId: bookingId,
                    tags: selectedTags.toList(),
                  )).future,
                );
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

class _StarFilters extends StatelessWidget {
  const _StarFilters({
    required this.selected,
    required this.reviews,
    required this.onSelected,
  });

  final int? selected;
  final List<Review> reviews;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var star = 1; star <= 5; star++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              selected: selected == star,
              label: Text(
                '$star★ (${reviews.where((r) => r.rating == star).length})',
              ),
              onSelected: (_) => onSelected(star),
            ),
          ),
      ],
    ),
  );
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
                CircleAvatar(
                  radius: 18,
                  backgroundImage: review.avatarUrl.isNotEmpty
                      ? NetworkImage(review.avatarUrl)
                      : null,
                  child: review.avatarUrl.isEmpty
                      ? Text(
                          (review.userName?.trim().isNotEmpty == true
                                  ? review.userName!.trim()[0]
                                  : '?')
                              .toUpperCase(),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    review.userName?.trim().isNotEmpty == true
                        ? review.userName!.trim()
                        : 'Anonymous Guest',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...List.generate(5, (i) {
                  return Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: AppTheme.accent,
                  );
                }),
                const SizedBox(width: 8),
                if (review.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Verified Booker',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: review.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                review.title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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

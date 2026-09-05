import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../domain/venue.dart';
import '../venue_providers.dart';
import 'venue_badges.dart';

/// A tappable venue card used in listings and the home screen.
class VenueCard extends ConsumerWidget {
  const VenueCard({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: favorite.when(
                      data: (isFav) => FavoriteButton(
                        isFavorite: isFav ?? false,
                        onPressed: () =>
                            ref.read(toggleFavoriteProvider(venue.id).future),
                      ),
                      loading: () => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                      error: (_, _) => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                    ),
                  ),
                  if (venue.distanceKm != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _LabelChip(
                        icon: Icons.near_me_outlined,
                        label: formatDistance(venue.distanceKm),
                      ),
                    ),
                  if (venue.avgRating > 0)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RatingBadge(
                          rating: venue.avgRating,
                          count: venue.ratingCount,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (venue.isVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          venue.city.isNotEmpty
                              ? venue.city
                              : venue.addressLine1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (venue.capacity > 0) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.groups_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${venue.capacity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.pricing} ${formatInr(venue.price)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact OYO-style result row used by the Function Hall results page.
/// It intentionally reads only fields already present on [Venue].
class FunctionHallListCard extends ConsumerWidget {
  const FunctionHallListCard({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final category = venue.category?.name;
    final facilities = venue.facilities
        .where((item) => item.isAvailable && item.facility.trim().isNotEmpty)
        .take(3)
        .map((item) => item.facility)
        .toList(growable: false);

    void openDetails() => context.push(
      AppRoutes.venueDetails.replaceAll(':id', venue.id),
    );
    void startBooking() => context.push(
      AppRoutes.bookingFlow.replaceAll(':id', venue.id),
      extra: venue,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 560;
          final image = SizedBox(
            width: horizontal ? 220 : double.infinity,
            height: horizontal ? 180 : 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  right: 8,
                  child: favorite.when(
                    data: (value) => FavoriteButton(
                      isFavorite: value ?? false,
                      onPressed: () => ref
                          .read(toggleFavoriteProvider(venue.id).future),
                    ),
                    loading: () => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                    error: (_, _) => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                  ),
                ),
                if (venue.distanceKm != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _LabelChip(
                      icon: Icons.near_me_outlined,
                      label: formatDistance(venue.distanceKm),
                    ),
                  ),
              ],
            ),
          );

          final details = Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (venue.isVerified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (venue.city.isNotEmpty) venue.city,
                    if (venue.state.isNotEmpty) venue.state,
                  ].join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    if (category != null && category.isNotEmpty)
                      _InfoPill(icon: Icons.category_outlined, label: category),
                    if (venue.avgRating > 0)
                      _InfoPill(
                        icon: Icons.star_rounded,
                        label: '${venue.avgRating.toStringAsFixed(1)} (${venue.ratingCount})',
                      ),
                    if (venue.capacity > 0)
                      _InfoPill(
                        icon: Icons.groups_outlined,
                        label: '${venue.capacity} guests',
                      ),
                    ...facilities.map(
                      (item) => _InfoPill(icon: Icons.check_circle_outline, label: item),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.price > 0 ? formatInr(venue.price) : 'Price on request',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: openDetails,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View Details'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: startBooking,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Book Now'),
                    ),
                  ],
                ),
              ],
            ),
          );

          return horizontal
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [image, Expanded(child: details)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [image, details]);
        },
      ),
    );
  }
}

/// Compact hotel result card. Room inventory is not part of the current
/// Venue model, so this card exposes the existing hotel venue and delegates
/// room/booking details to the established venue details flow.
class HotelListCard extends ConsumerWidget {
  const HotelListCard({super.key, required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));
    final facilities = venue.facilities
        .where((item) => item.isAvailable && item.facility.trim().isNotEmpty)
        .take(4)
        .map((item) => item.facility)
        .toList(growable: false);

    void details() => context.push(
      AppRoutes.venueDetails.replaceAll(':id', venue.id),
    );
    void book() => context.push(
      AppRoutes.bookingFlow.replaceAll(':id', venue.id),
      extra: venue,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 560;
          final image = SizedBox(
            width: horizontal ? 230 : double.infinity,
            height: horizontal ? 190 : 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
                Positioned(
                  top: 8,
                  right: 8,
                  child: favorite.when(
                    data: (value) => FavoriteButton(
                      isFavorite: value ?? false,
                      onPressed: () => ref
                          .read(toggleFavoriteProvider(venue.id).future),
                    ),
                    loading: () => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                    error: (_, _) => const FavoriteButton(
                      isFavorite: false,
                      onPressed: null,
                    ),
                  ),
                ),
                if (venue.images.length > 1)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _LabelChip(
                      icon: Icons.photo_library_outlined,
                      label: '1/${venue.images.length}',
                    ),
                  ),
              ],
            ),
          );
          final content = Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (venue.isVerified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (venue.city.isNotEmpty) venue.city,
                    if (venue.state.isNotEmpty) venue.state,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    if (venue.avgRating > 0)
                      _InfoPill(
                        icon: Icons.star_rounded,
                        label: '${venue.avgRating.toStringAsFixed(1)} (${venue.ratingCount})',
                      ),
                    ...facilities.map(
                      (item) => _InfoPill(icon: Icons.check_circle_outline, label: item),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.price > 0 ? '${formatInr(venue.price)} / night' : 'Price on request',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: details,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View Hotel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: book,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Book Stay'),
                    ),
                  ],
                ),
              ],
            ),
          );
          return horizontal
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [image, Expanded(child: content)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [image, content]);
        },
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Compact, redBus/OYO-style vertical hotel card for browsing "Lodge / Rooms"
/// stays. Deliberately simple: a colored rating pill on the image, name +
/// location, and a single price row with one primary "Book Now" action --
/// mirrors the lean hotel-listing pattern used by redBus/OYO-style booking
/// apps, built only from fields that already exist on [Venue] (no invented
/// pricing/discount data).
class HotelStyleVenueCard extends ConsumerWidget {
  const HotelStyleVenueCard({
    super.key,
    required this.venue,
    required this.onTap,
    required this.onBookTap,
  });

  final Venue venue;
  final VoidCallback onTap;
  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover),
                  if (venue.avgRating > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B7A4C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              venue.avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: favorite.when(
                      data: (isFav) => FavoriteButton(
                        isFavorite: isFav ?? false,
                        onPressed: () =>
                            ref.read(toggleFavoriteProvider(venue.id).future),
                      ),
                      loading: () => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                      error: (_, _) => const FavoriteButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                    ),
                  ),
                  if (venue.ratingCount > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${venue.ratingCount} ratings',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (venue.isVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          venue.city.isNotEmpty
                              ? venue.city
                              : venue.addressLine1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: venue.pricingBaseAmount > 0
                                    ? '₹${venue.pricingBaseAmount.toInt()}'
                                    : 'Price on request',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              if (venue.pricingBaseAmount > 0)
                                TextSpan(
                                  text: ' / night',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onBookTap,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

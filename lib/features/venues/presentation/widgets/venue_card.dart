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
  const VenueCard({super.key, required this.venue, this.compact = false});

  final Venue venue;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(isFavoriteProvider(venue.id));

    if (compact) {
      return _CompactVenueCard(
        venue: venue,
        favorite: favorite,
        onTap: () =>
            context.push(AppRoutes.venueDetails.replaceAll(':id', venue.id)),
        onFavorite: () => ref.read(toggleFavoriteProvider(venue.id).future),
      );
    }

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

class _CompactVenueCard extends StatelessWidget {
  const _CompactVenueCard({
    required this.venue,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Venue venue;
  final AsyncValue<bool?> favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: '${venue.name}, ${venue.city}',
        button: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 116,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 88,
                    height: 96,
                    child: AppNetworkImage(
                      url: venue.coverImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brand.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'VENUE',
                          style: TextStyle(
                            color: AppTheme.brand,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        venue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                              [
                                if (venue.city.isNotEmpty) venue.city,
                                if (venue.distanceKm != null)
                                  formatDistance(venue.distanceKm),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (venue.avgRating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF59E0B),
                              size: 14,
                            ),
                            Text(
                              venue.avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${formatInr(venue.price)} / day',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                favorite.when(
                  data: (value) => IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      value ?? false
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: value ?? false
                          ? const Color(0xFFE11D48)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  loading: () => const SizedBox(width: 40),
                  error: (_, _) => const SizedBox(width: 40),
                ),
              ],
            ),
          ),
        ),
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

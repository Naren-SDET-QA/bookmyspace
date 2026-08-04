import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
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
    final emoji = PrototypeVisuals.emojiForCategorySlug(
      venue.category?.slug,
      icon: venue.category?.icon,
    );

    if (compact) {
      return _CompactVenueCard(
        venue: venue,
        emoji: emoji,
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
                  if (venue.coverImageUrl.isNotEmpty)
                    AppNetworkImage(url: venue.coverImageUrl, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: PrototypeVisuals.thumbGradientFor(venue.id),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: PrototypeVisuals.emojiStyle(fontSize: 52),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: favorite.when(
                      data: (isFav) => PrototypeFavButton(
                        isFavorite: isFav ?? false,
                        onPressed: () =>
                            ref.read(toggleFavoriteProvider(venue.id).future),
                      ),
                      loading: () => const PrototypeFavButton(
                        isFavorite: false,
                        onPressed: null,
                      ),
                      error: (_, _) => const PrototypeFavButton(
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
                          color: Colors.white.withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(11),
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
                      const PrototypeBadge.venue(),
                      const Spacer(),
                      if (venue.isVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
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
                            fontWeight: FontWeight.w600,
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatInr(venue.price),
                          style: const TextStyle(
                            color: AppTheme.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        TextSpan(
                          text: ' /day',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Keep pricing a11y label available for screen readers.
                  Semantics(
                    label: '${l10n.pricing} ${formatInr(venue.price)}',
                    excludeSemantics: true,
                    child: const SizedBox.shrink(),
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
    required this.emoji,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Venue venue;
  final String emoji;
  final AsyncValue<bool?> favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = venue.coverImageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Semantics(
          label: '${venue.name}, ${venue.city}',
          button: true,
          child: Ink(
            decoration: PrototypeVisuals.cardDecoration(),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(11),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: SizedBox(
                            width: 82,
                            height: 88,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: PrototypeVisuals.thumbGradientFor(
                                      venue.id,
                                    ),
                                  ),
                                ),
                                if (hasImage)
                                  AppNetworkImage(
                                    url: venue.coverImageUrl,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  Center(
                                    child: Text(
                                      emoji,
                                      style: PrototypeVisuals.emojiStyle(
                                        fontSize: 34,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  PrototypeBadge.venue(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                venue.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
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
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                  if (venue.avgRating > 0) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      color: PrototypeVisuals.star,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      venue.avgRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: PrototypeVisuals.starText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: formatInr(venue.price),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' /day',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PrototypeVisuals.availBg,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Text(
                                      'Available',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: favorite.when(
                    data: (value) => PrototypeFavButton(
                      isFavorite: value ?? false,
                      onPressed: onFavorite,
                    ),
                    loading: () =>
                        const PrototypeFavButton(isFavorite: false),
                    error: (_, _) =>
                        const PrototypeFavButton(isFavorite: false),
                  ),
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
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

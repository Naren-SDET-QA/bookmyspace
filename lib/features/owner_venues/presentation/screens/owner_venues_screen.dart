import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../providers/owner_venue_providers.dart';

/// Screen showing venues owned by the current owner.
class OwnerVenuesScreen extends ConsumerWidget {
  const OwnerVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final venues = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myVenues),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.ownerVenueCreate),
          ),
        ],
      ),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myVenuesProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.storefront_rounded,
                title: 'No venues yet',
                message: 'Tap + to add your first venue.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _VenueTile(venue: items[i]),
              ),
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.ownerVenueEdit.replaceAll(':id', venue.id),
          extra: venue,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      venue.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusBadge(venue: venue, theme: theme),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${venue.city}, ${venue.state}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    venue.avgRating.toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${venue.ratingCount})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${venue.pricingBaseAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.venue, required this.theme});

  final Venue venue;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _state();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (String, Color, Color) _state() {
    if (venue.isActive) {
      return (
        '✅ Live',
        AppTheme.brand.withValues(alpha: 0.12),
        AppTheme.brand,
      );
    }
    if (!venue.isVerified) {
      return (
        '⏳ Under review',
        theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        theme.colorScheme.onTertiaryContainer,
      );
    }
    return (
      '⛔ Inactive',
      theme.colorScheme.error.withValues(alpha: 0.12),
      theme.colorScheme.error,
    );
  }
}

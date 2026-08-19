import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../home/domain/customer_section_catalog.dart';
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
            onPressed: () async {
              await context.push(AppRoutes.ownerVenueCreate);
              ref.invalidate(myVenuesProvider);
            },
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
                title: 'No listings yet',
                message: 'Tap + to add a Function Hall, Lodge, PG or Institute.',
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

class _VenueTile extends ConsumerWidget {
  const _VenueTile({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final section = CustomerSectionCatalog.sectionForVenue(venue);
    final institute = section == CustomerSection.institutesClasses;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(
                    url: venue.coverImageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (section != null) '${section.emoji} ${section.title}',
                          '${venue.city}, ${venue.state}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: venue.isActive
                        ? AppTheme.brand.withValues(alpha: 0.12)
                        : theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    venue.isActive ? 'Published' : 'Draft',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: venue.isActive
                          ? AppTheme.brand
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  institute
                      ? 'Fee from ₹${venue.pricingBaseAmount.toStringAsFixed(0)}'
                      : '₹${venue.pricingBaseAmount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brand,
                  ),
                ),
                if (institute) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Listing only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (!venue.isVerified)
                  Text(
                    'Pending review',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    await context.push(AppRoutes.ownerVenueEditPath(venue.id));
                    ref.invalidate(myVenuesProvider);
                  },
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => context.push('/venues/${venue.id}'),
                  child: const Text('Preview'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(ownerVenueRepositoryProvider).setPublished(
                      venue.id,
                      !venue.isActive,
                    );
                    ref.invalidate(myVenuesProvider);
                  },
                  child: Text(venue.isActive ? 'Unpublish' : 'Publish'),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete listing?'),
                        content: Text(
                          'Remove "${venue.name}" from your listings. This uses the existing owner delete.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await ref
                        .read(ownerVenueRepositoryProvider)
                        .deleteVenue(venue.id);
                    ref.invalidate(myVenuesProvider);
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Home feed: greeting, category chips and venue cards.
///
/// Real venue data is wired in Milestone 3. The layout matches the prototype's
/// home structure so it can be populated without rework.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeGreeting, style: theme.textTheme.labelLarge),
            Text(
              l10n.findYourSpace,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.whatAreYouLookingFor, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _CategoryChips(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.nearbyVenues, style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push(
                    AppRoutes.venueDetails.replaceAll(':id', 'demo'),
                  ),
                  child: Text(l10n.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _VenuePlaceholder(),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  static const _categories = [
    (Icons.celebration_rounded, 'Function Hall'),
    (Icons.favorite_rounded, 'Marriage Hall'),
    (Icons.groups_rounded, 'Meeting Room'),
    (Icons.sports_soccer_rounded, 'Sports'),
    (Icons.theaters_rounded, 'Auditorium'),
    (Icons.work_rounded, 'Coworking'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final (icon, label) = _categories[i];
          return Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
                child: Icon(icon, color: AppTheme.brand),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          );
        },
      ),
    );
  }
}

class _VenuePlaceholder extends StatelessWidget {
  const _VenuePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            color: AppTheme.brand.withValues(alpha: 0.15),
            alignment: Alignment.center,
            child: const Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: AppTheme.brandLight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coming soon',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Venue listings populate in Milestone 3.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

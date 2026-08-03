import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../courses/presentation/course_providers.dart';
import '../../../courses/presentation/widgets/course_card.dart';
import '../../../events/presentation/event_providers.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Home feed: greeting, category chips, popular + nearby venue lists.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final popular = ref.watch(popularVenuesProvider);
    final nearby = ref.watch(nearbyVenuesProvider);
    final categories = ref.watch(venueCategoriesProvider);
    final events = ref.watch(upcomingEventsProvider);
    final courses = ref.watch(publishedCoursesProvider);

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
        onRefresh: () async {
          ref.invalidate(popularVenuesProvider);
          ref.invalidate(nearbyVenuesProvider);
          ref.invalidate(venueCategoriesProvider);
          ref.invalidate(upcomingEventsProvider);
          ref.invalidate(publishedCoursesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.whatAreYouLookingFor, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            categories.when(
              data: (cats) => _CategoryChips(
                categories: cats,
                onTap: (slug) =>
                    context.push(AppRoutes.search, extra: {'category': slug}),
              ),
              loading: () => const SkeletonBox(height: 92, radius: 16),
              error: (_, _) => const SizedBox(height: 92),
            ),
            const SizedBox(height: 24),
            _DynamicSection(
              async: events,
              title: l10n.upcomingEvents,
              onViewAll: () => context.push(AppRoutes.eventsList),
              loading: const _LoadingCardRow(),
              itemBuilder: (items) => _HorizontalList(
                items: items
                    .map(
                      (e) => SizedBox(width: 280, child: EventCard(event: e)),
                    )
                    .toList(),
              ),
            ),
            _DynamicSection(
              async: courses,
              title: l10n.courses,
              onViewAll: () => context.push(AppRoutes.coursesList),
              loading: const _LoadingCardRow(),
              itemBuilder: (items) => _HorizontalList(
                items: items
                    .map(
                      (c) => SizedBox(width: 280, child: CourseCard(course: c)),
                    )
                    .toList(),
              ),
            ),
            _SectionHeader(title: l10n.popularVenues, onViewAll: null),
            const SizedBox(height: 8),
            popular.when(
              data: (venues) => _VenueGrid(venues: venues),
              loading: () => const _LoadingGrid(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(popularVenuesProvider),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: l10n.nearbyVenues, onViewAll: null),
            const SizedBox(height: 8),
            nearby.when(
              data: (venues) => venues.isEmpty
                  ? const EmptyState(
                      icon: Icons.location_searching,
                      title: 'No venues nearby',
                      message: 'Try widening your search later.',
                    )
                  : _VenueGrid(venues: venues),
              loading: () => const _LoadingGrid(),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(nearbyVenuesProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, this.onTap});

  final List<VenueCategory> categories;
  final void Function(String slug)? onTap;

  static const _icons = <String, IconData>{
    'function_hall': Icons.celebration_rounded,
    'marriage_hall': Icons.favorite_rounded,
    'convention_center': Icons.business_center_rounded,
    'party_hall': Icons.nightlife_rounded,
    'meeting_room': Icons.groups_rounded,
    'community_hall': Icons.diversity_3_rounded,
    'sports_ground': Icons.sports_soccer_rounded,
    'coworking_space': Icons.work_rounded,
    'auditorium': Icons.theaters_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final icon = _icons[cat.slug] ?? Icons.apartment_rounded;
          return InkWell(
            onTap: onTap == null ? null : () => onTap!(cat.slug),
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.brand.withValues(alpha: 0.12),
                  child: Icon(icon, color: AppTheme.brand),
                ),
                const SizedBox(height: 6),
                Text(cat.name, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Two-column responsive grid of [VenueCard]s.
class _VenueGrid extends StatelessWidget {
  const _VenueGrid({required this.venues});

  final List<Venue> venues;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: venues.length,
      itemBuilder: (context, i) => VenueCard(venue: venues[i]),
    );
  }
}

/// A horizontal, scrollable row of fixed-width cards.
class _HorizontalList extends StatelessWidget {
  const _HorizontalList({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) => items[i],
      ),
    );
  }
}

/// Renders a titled horizontal section only when the data is non-empty.
class _DynamicSection<T> extends StatelessWidget {
  const _DynamicSection({
    required this.async,
    required this.title,
    required this.onViewAll,
    required this.itemBuilder,
    required this.loading,
  });

  final AsyncValue<List<T>> async;
  final String title;
  final VoidCallback? onViewAll;
  final Widget Function(List<T> items) itemBuilder;
  final Widget loading;

  @override
  Widget build(BuildContext context) {
    if (async.isLoading && !async.hasValue) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            loading,
          ],
        ),
      );
    }
    final items = async.valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, onViewAll: onViewAll),
          const SizedBox(height: 8),
          itemBuilder(items),
        ],
      ),
    );
  }
}

class _LoadingCardRow extends StatelessWidget {
  const _LoadingCardRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 260,
      child: Row(
        children: [
          Expanded(child: SkeletonBox(height: 260, radius: 16)),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 260, radius: 16)),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: SkeletonBox(height: 240, radius: 16)),
        SizedBox(width: 12),
        Expanded(child: SkeletonBox(height: 240, radius: 16)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/location/device_location_service.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
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
    final events = ref.watch(upcomingEventsProvider);
    final courses = ref.watch(publishedCoursesProvider);
    final repository = ref.watch(authRepositoryProvider);
    final searchArea = ref.watch(searchAreaProvider);
    final user =
        ref.watch(authStateProvider).asData?.value ?? repository.currentUser;
    final displayName = user == null
        ? null
        : (user.fullName.trim().isNotEmpty
              ? user.fullName.trim()
              : user.email.trim());

    if (MediaQuery.sizeOf(context).width >= 600) {
      return _WideHome(
        displayName: displayName,
        popular: popular,
        nearby: nearby,
        searchArea: searchArea,
        onRefresh: () async {
          ref.invalidate(popularVenuesProvider);
          ref.invalidate(nearbyVenuesProvider);
        },
        onPopularRetry: () => ref.invalidate(popularVenuesProvider),
        onNearbyRetry: () => ref.invalidate(nearbyVenuesProvider),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularVenuesProvider);
          ref.invalidate(nearbyVenuesProvider);
          ref.invalidate(venueCategoriesProvider);
          ref.invalidate(upcomingEventsProvider);
          ref.invalidate(publishedCoursesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => _showLocationPicker(context, ref),
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.brandLight, AppTheme.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your location',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  searchArea.cityLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 17,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: const Badge(
                      smallSize: 8,
                      child: Icon(Icons.notifications_outlined),
                    ),
                    tooltip: 'Notifications',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                displayName == null
                    ? 'Welcome to Guest'
                    : 'Welcome, $displayName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'What will you '),
                    TextSpan(
                      text: 'book today?',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.go(AppRoutes.search),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Search halls, classes, events…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _PrimaryCategories(),
              const SizedBox(height: 10),
              const _RadiusSelector(),
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
                        (c) =>
                            SizedBox(width: 280, child: CourseCard(course: c)),
                      )
                      .toList(),
                ),
              ),
              _SectionHeader(
                title: l10n.popularVenues,
                onViewAll: () => context.go(AppRoutes.search),
              ),
              const SizedBox(height: 8),
              popular.when(
                data: (venues) => _VenueList(venues: venues),
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
                    : _VenueList(venues: venues),
                loading: () => const _LoadingGrid(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(nearbyVenuesProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showLocationPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(searchAreaProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose location',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_rounded),
                title: const Text('Use my current location'),
                subtitle: const Text('Uses GPS to find venues near you'),
                onTap: () => _useCurrentLocation(context, ref),
              ),
              for (final entry in kSearchCities.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  trailing: entry.value.cityLabel == current.cityLabel
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.brand,
                        )
                      : null,
                  onTap: () {
                    ref.read(searchAreaProvider.notifier).state = entry.value;
                    ref.invalidate(nearbyVenuesProvider);
                    final query = ref.read(searchQueryProvider);
                    ref.read(searchQueryProvider.notifier).state = query.copyWith(
                      city: () => entry.key,
                      latitude: () => entry.value.latitude,
                      longitude: () => entry.value.longitude,
                    );
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _useCurrentLocation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    messenger.showSnackBar(
      const SnackBar(content: Text('Getting your location…')),
    );

    final result = await ref.read(deviceLocationServiceProvider).currentPosition();
    if (!context.mounted) return;

    switch (result) {
      case DeviceLocationSuccess(:final latitude, :final longitude):
        final area = gpsSearchArea(latitude, longitude);
        ref.read(searchAreaProvider.notifier).state = area;
        ref.invalidate(nearbyVenuesProvider);
        final query = ref.read(searchQueryProvider);
        ref.read(searchQueryProvider.notifier).state = query.copyWith(
          city: () => null,
          latitude: () => latitude,
          longitude: () => longitude,
        );
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Showing venues near your location')),
        );
      case DeviceLocationPermissionDenied():
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. Choose a city or enable location in settings.',
            ),
          ),
        );
      case DeviceLocationServiceDisabled():
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are off. Turn them on or pick a city manually.',
            ),
          ),
        );
      case DeviceLocationUnavailable(:final message):
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not get location. Try again or pick a city. ($message)',
            ),
          ),
        );
    }
  }
}

class _WideHome extends ConsumerWidget {
  const _WideHome({
    required this.displayName,
    required this.popular,
    required this.nearby,
    required this.searchArea,
    required this.onRefresh,
    required this.onPopularRetry,
    required this.onNearbyRetry,
  });

  final AsyncValue<List<Venue>> popular;
  final String? displayName;
  final AsyncValue<List<Venue>> nearby;
  final SearchArea searchArea;
  final Future<void> Function() onRefresh;
  final VoidCallback onPopularRetry;
  final VoidCallback onNearbyRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName == null ? 'Welcome to Guest' : 'Welcome, $displayName',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'Find your perfect space',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        Semantics(
          label: 'Change location, currently ${searchArea.cityLabel}',
          button: true,
          child: InkWell(
            onTap: () => HomeScreen._showLocationPicker(context, ref),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    searchArea.cityLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => context.push(AppRoutes.notifications),
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Notifications',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.search),
            child: const IgnorePointer(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search halls, classes, events…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Function Hall'),
                onPressed: () => _openPrimaryCategory(context, 'function_hall'),
              ),
              ActionChip(
                label: const Text('Classes'),
                onPressed: () => _openPrimaryCategory(context, 'classes'),
              ),
              ActionChip(
                label: const Text('Events'),
                onPressed: () => _openPrimaryCategory(context, 'events'),
              ),
              ActionChip(
                label: const Text('Meetings'),
                onPressed: () => _openPrimaryCategory(context, 'meeting_room'),
              ),
              ActionChip(
                label: const Text('PG / Co-Living'),
                onPressed: () => _openPrimaryCategory(context, 'pg'),
              ),
              ActionChip(
                label: const Text('Rooms & Stays'),
                onPressed: () => _openPrimaryCategory(context, 'stays'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionHeader(title: 'Popular venues'),
          const SizedBox(height: 8),
          popular.when(
            data: (venues) => _VenueList(venues: venues),
            loading: () => const _LoadingGrid(),
            error: (error, _) =>
                ErrorView(message: error.toString(), onRetry: onPopularRetry),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Nearby venues'),
          const SizedBox(height: 8),
          nearby.when(
            data: (venues) => _VenueList(venues: venues),
            loading: () => const _LoadingGrid(),
            error: (error, _) =>
                ErrorView(message: error.toString(), onRetry: onNearbyRetry),
          ),
        ],
      ),
    ),
  );
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

class _PrimaryCategories extends StatelessWidget {
  const _PrimaryCategories();

  static const _items = [
    (Icons.celebration_rounded, 'Function halls', 'function_hall'),
    (Icons.school_rounded, 'Classes', 'classes'),
    (Icons.event_rounded, 'Events', 'events'),
    (Icons.groups_rounded, 'Meetings', 'meeting_room'),
    (Icons.apartment_rounded, 'PG / Co-Living', 'pg'),
    (Icons.hotel_rounded, 'Rooms & Stays', 'stays'),
    (Icons.sports_soccer_rounded, 'Sports', 'sports_ground'),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: .88,
    ),
    itemCount: _items.length,
    itemBuilder: (context, index) {
      final item = _items[index];
      return InkWell(
        key: ValueKey('home-category-${item.$3}'),
        onTap: () => _openPrimaryCategory(context, item.$3),
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.$1, color: AppTheme.brand, size: 25),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  item.$2,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _openPrimaryCategory(BuildContext context, String category) {
  switch (category) {
    case 'classes':
      context.push(AppRoutes.coursesList);
      return;
    case 'events':
      context.push(AppRoutes.eventsList);
      return;
    case 'pg':
      context.push(AppRoutes.pgList);
      return;
    case 'stays':
      context.push(AppRoutes.staysList);
      return;
    case 'meeting_room':
      context.push(AppRoutes.meetingRooms);
      return;
    case 'sports_ground':
      context.push(AppRoutes.sportsVenues);
      return;
    default:
      context.go(
        Uri(
          path: AppRoutes.search,
          queryParameters: {'category': category},
        ).toString(),
      );
      return;
  }
}

class _RadiusSelector extends ConsumerWidget {
  const _RadiusSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(searchRadiusKmProvider);
  return SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        Center(
          child: Text(
            'Show within',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (final radius in const [3.0, 5.0, 10.0, 25.0]) ...[
          ChoiceChip(
            label: Text('${radius.toInt()} km'),
            selected: selected == radius,
            onSelected: (_) {
              ref.read(searchRadiusKmProvider.notifier).state = radius;
              ref.invalidate(nearbyVenuesProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
  }
}

/// Two-column responsive grid of [VenueCard]s.
class _VenueList extends StatelessWidget {
  const _VenueList({required this.venues});

  final List<Venue> venues;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(height: 11),
      itemBuilder: (context, i) => VenueCard(venue: venues[i], compact: true),
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

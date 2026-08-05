import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/location/device_location_service.dart';
import '../../../../core/location/location_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../admin/domain/content_models.dart';
import '../../../admin/presentation/content_providers.dart';
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
    final searchArea = ref.watch(searchAreaProvider);
    // Rebuild when session restores so location/greeting stay in sync.
    ref.watch(authStateProvider);

    if (MediaQuery.sizeOf(context).width >= 600) {
      return _WideHome(
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
      backgroundColor: AppTheme.surfaceLight,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularVenuesProvider);
          ref.invalidate(nearbyVenuesProvider);
          ref.invalidate(venueCategoriesProvider);
          ref.invalidate(upcomingEventsProvider);
          ref.invalidate(publishedCoursesProvider);
          ref.invalidate(homepageContentConfigProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showLocationPicker(context, ref),
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: AppTheme.brandGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current location',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.muted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        searchArea.cityLabel,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.ink,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 13,
                                      color: AppTheme.ink,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrototypeIconButton(
                    icon: Icons.notifications_outlined,
                    showDot: true,
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                PrototypeVisuals.timeGreeting(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(text: 'What are you '),
                    TextSpan(
                      text: 'looking for?',
                      style: TextStyle(color: AppTheme.brand),
                    ),
                  ],
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                  fontSize: 24,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => context.go(AppRoutes.search),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: PrototypeVisuals.searchFieldDecoration(),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: PrototypeVisuals.searchHint,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search halls, classes, events…',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PrototypeVisuals.searchHint,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _HeroBanner(),
              const SizedBox(height: 18),
              const _PrimaryCategories(),
              const SizedBox(height: 4),
              const _RadiusSelector(),
              const _PopularCities(),
              const SizedBox(height: 12),
              _DynamicSection(
                async: events,
                title: '⚡ Happening near you',
                onViewAll: () => context.push(AppRoutes.eventsList),
                loading: const _LoadingCardRow(),
                itemBuilder: (items) => _HorizontalList(
                  height: 198,
                  items: items
                      .map(
                        (e) => SizedBox(width: 208, child: EventCard(event: e)),
                      )
                      .toList(),
                ),
              ),
              _DynamicSection(
                async: courses,
                title: '🎓 Popular institutes',
                onViewAll: () => context.push(AppRoutes.coursesList),
                loading: const _LoadingCardRow(),
                itemBuilder: (items) => _HorizontalList(
                  height: 220,
                  items: items
                      .map(
                        (c) =>
                            SizedBox(width: 240, child: CourseCard(course: c)),
                      )
                      .toList(),
                ),
              ),
              _SectionHeader(
                title: '🏛️ Halls free this weekend',
                onViewAll: () => context.go(AppRoutes.search),
              ),
              const SizedBox(height: 12),
              popular.when(
                data: (venues) => _VenueList(venues: venues),
                loading: () => const _LoadingGrid(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(popularVenuesProvider),
                ),
              ),
              const SizedBox(height: 24),
              _DynamicSection(
                async: popular,
                title: '🔥 Trending now',
                onViewAll: () => context.go(AppRoutes.search),
                loading: const _LoadingCardRow(),
                itemBuilder: (venues) => _HorizontalList(
                  height: 186,
                  items: venues
                      .take(6)
                      .map(
                        (v) => SizedBox(
                          width: 250,
                          child: AnimatedEntrance(
                            child: VenueCard(venue: v, compact: true),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              _DynamicSection(
                async: nearby,
                title: '✨ Recommended for you',
                onViewAll: null,
                loading: const _LoadingCardRow(),
                itemBuilder: (venues) => _HorizontalList(
                  height: 186,
                  items: venues
                      .take(6)
                      .map(
                        (v) => SizedBox(
                          width: 250,
                          child: AnimatedEntrance(
                            child: VenueCard(venue: v, compact: true),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              _SpecialOffers(popular: popular),
              _RecentlyViewed(),
              const SizedBox(height: 24),
              _SectionHeader(title: '📍 Nearby venues', onViewAll: null),
              const SizedBox(height: 12),
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
    await showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.78,
      builder: (sheetContext) {
        final cities = kSearchCities.entries.toList(growable: false);
        return AppBottomSheetScrollBody(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose location',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                  PrototypeIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Material(
                color: AppTheme.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: AppTheme.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => _useCurrentLocation(sheetContext, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: PrototypeVisuals.softIconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.brand,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.muted,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                'Use my current location',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'OR SEARCH A CITY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.muted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              for (final entry in cities)
                InkWell(
                  onTap: () {
                    ref.read(searchAreaProvider.notifier).state = entry.value;
                    ref.invalidate(nearbyVenuesProvider);
                    final query = ref.read(searchQueryProvider);
                    ref.read(searchQueryProvider.notifier).state = query
                        .copyWith(
                          city: () => entry.key,
                          latitude: () => entry.value.latitude,
                          longitude: () => entry.value.longitude,
                        );
                    Navigator.pop(sheetContext);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 4,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: PrototypeVisuals.menuRowBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (entry.value.cityLabel == current.cityLabel)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PrototypeVisuals.badgeVenueBg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                color: AppTheme.brand,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
    required this.popular,
    required this.nearby,
    required this.searchArea,
    required this.onRefresh,
    required this.onPopularRetry,
    required this.onNearbyRetry,
  });

  final AsyncValue<List<Venue>> popular;
  final AsyncValue<List<Venue>> nearby;
  final SearchArea searchArea;
  final Future<void> Function() onRefresh;
  final VoidCallback onPopularRetry;
  final VoidCallback onNearbyRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppTheme.surfaceLight,
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PrototypeVisuals.timeGreeting(),
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'What are you looking for?',
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.go(AppRoutes.search),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: PrototypeVisuals.searchFieldDecoration(),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: PrototypeVisuals.searchHint,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search halls, classes, events…',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PrototypeVisuals.searchHint,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: const _PrimaryCategories(),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionHeader(title: '🏛️ Popular venues'),
            const SizedBox(height: 12),
            popular.when(
              data: (venues) => _VenueList(venues: venues),
              loading: () => const _LoadingGrid(),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: onPopularRetry,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: '📍 Nearby venues'),
            const SizedBox(height: 12),
            nearby.when(
              data: (venues) => _VenueList(venues: venues),
              loading: () => const _LoadingGrid(),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: onNearbyRetry,
              ),
            ),
          ],
        ),
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
    // Prototype `.secHead`: margin 24px 0 12px; h2 16.5/800; See all 12/700 pri
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                letterSpacing: -0.3,
                color: AppTheme.ink,
                fontFamilyFallback: AppTheme.emojiFontFallbacks,
              ),
            ),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryCategories extends ConsumerWidget {
  const _PrimaryCategories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(homepageContentConfigProvider);
    final tiles = _withCoreTiles(
      remote.maybeWhen(
        data: (cfg) => cfg.categoryTiles.isNotEmpty
            ? cfg.categoryTiles
            : _fallbackTiles(),
        orElse: _fallbackTiles,
      ),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Prototype catT is roughly square (emoji 23 + label + padding).
        childAspectRatio: 1.02,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final item = tiles[index];
        return PrototypeCategoryTile(
          key: ValueKey('home-category-${item.tileKey}'),
          emoji: PrototypeVisuals.emojiForCategorySlug(
            item.tileKey,
            icon: item.emoji,
          ),
          label: item.label,
          onTap: () => _openPrimaryCategory(
            context,
            item.routeTarget.isNotEmpty ? item.routeTarget : item.tileKey,
          ),
        );
      },
    );
  }

  static List<HomeCategoryTile> _fallbackTiles() => [
        for (final c in PrototypeVisuals.homeCategories)
          HomeCategoryTile(
            id: c.key,
            tileKey: c.key,
            label: c.label,
            emoji: c.emoji,
            routeTarget: c.key,
          ),
      ];

  /// Guarantees PG / Co-Living and Hotels / Rooms / Stays always appear on
  /// Home, appended when the remote/admin tile config does not define them.
  static List<HomeCategoryTile> _withCoreTiles(List<HomeCategoryTile> tiles) {
    if (tiles.any((t) => t.tileKey == 'pg') &&
        tiles.any((t) => t.tileKey == 'stays')) {
      return tiles;
    }
    final result = List<HomeCategoryTile>.of(tiles);
    if (!tiles.any((t) => t.tileKey == 'pg')) {
      result.add(const HomeCategoryTile(
        id: 'pg',
        tileKey: 'pg',
        label: 'PG / Co-Living',
        emoji: '🏠',
        routeTarget: 'pg',
      ));
    }
    if (!tiles.any((t) => t.tileKey == 'stays')) {
      result.add(const HomeCategoryTile(
        id: 'stays',
        tileKey: 'stays',
        label: 'Hotels / Rooms / Stays',
        emoji: '🛏️',
        routeTarget: 'stays',
      ));
    }
    return result;
  }
}

void _openPrimaryCategory(BuildContext context, String categoryOrRoute) {
  final category = categoryOrRoute.contains(':')
      ? categoryOrRoute.split(':').last
      : categoryOrRoute;
  final target = categoryOrRoute.contains(':')
      ? categoryOrRoute.split(':').first
      : categoryOrRoute;

  switch (target) {
    case 'courses':
    case 'classes':
      context.push(AppRoutes.coursesList);
      return;
    case 'events':
    case 'conferences':
    case 'parties':
    case 'shows':
      context.push(AppRoutes.eventsList);
      return;
    case 'pg':
      context.push(AppRoutes.pgList);
      return;
    case 'stays':
      context.push(AppRoutes.staysList);
      return;
    case 'meeting_rooms':
    case 'meeting_room':
      context.push(AppRoutes.meetingRooms);
      return;
    case 'sports':
    case 'sports_ground':
      context.push(AppRoutes.sportsVenues);
      return;
    case 'search':
      context.go(
        Uri(
          path: AppRoutes.search,
          queryParameters: {'category': category},
        ).toString(),
      );
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
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Center(
              child: Text(
                '📍 Within',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                  fontFamilyFallback: AppTheme.emojiFontFallbacks,
                ),
              ),
            ),
            const SizedBox(width: 8),
            for (final radius in PrototypeVisuals.radiusOptionsKm) ...[
              _RadiusChip(
                label: PrototypeVisuals.radiusLabel(radius),
                selected: selected == radius,
                onTap: () {
                  ref.read(searchRadiusKmProvider.notifier).state = radius;
                  ref.invalidate(nearbyVenuesProvider);
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PrototypeFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
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
///
/// Matches prototype `.hScroll` edge bleed (`margin: 0 -18px; padding: 0 18px`).
class _HorizontalList extends StatelessWidget {
  const _HorizontalList({required this.items, this.height = 260});

  final List<Widget> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Bleed past the parent 18px pad like prototype `.hScroll`.
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
        clipBehavior: Clip.none,
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
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                letterSpacing: -0.3,
                color: AppTheme.ink,
                fontFamilyFallback: AppTheme.emojiFontFallbacks,
              ),
            ),
            const SizedBox(height: 12),
            loading,
          ],
        ),
      );
    }
    final items = async.valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, onViewAll: onViewAll),
          const SizedBox(height: 12),
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

/// Prototype-style promo hero: gradient card with tagline and a search CTA.
class _HeroBanner extends ConsumerWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(searchAreaProvider);
    final city = area.cityLabel.split(',').first;
    return AnimatedEntrance(
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF6C3DF4), Color(0xFF4F46E5)],
            ),
          ),
          child: InkWell(
            onTap: () => context.go(AppRoutes.search),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            '⭐ FEATURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Discover spaces\nnear $city',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.explore_rounded,
                                    size: 14,
                                    color: AppTheme.brand,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Explore now',
                                    style: TextStyle(
                                      color: AppTheme.brand,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '🏛️',
                    style: TextStyle(
                      fontSize: 58,
                      fontFamilyFallback: AppTheme.emojiFontFallbacks,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prototype `.radRow`-style horizontal city chips (short names only, so they
/// never collide with the location picker sheet labels).
class _PopularCities extends ConsumerWidget {
  const _PopularCities();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(searchAreaProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            const Center(
              child: Text(
                '🌆 Popular',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                  fontFamilyFallback: AppTheme.emojiFontFallbacks,
                ),
              ),
            ),
            const SizedBox(width: 8),
            for (final entry in kSearchCities.entries) ...[
              _CityChip(
                label: entry.key,
                selected: entry.value.cityLabel == current.cityLabel,
                onTap: () {
                  ref.read(searchAreaProvider.notifier).state = entry.value;
                  ref.invalidate(nearbyVenuesProvider);
                  final query = ref.read(searchQueryProvider);
                  ref.read(searchQueryProvider.notifier).state = query.copyWith(
                    city: () => entry.key,
                    latitude: () => entry.value.latitude,
                    longitude: () => entry.value.longitude,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.ink : AppTheme.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppTheme.ink : AppTheme.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of venues carrying an offer, when any exist.
class _SpecialOffers extends StatelessWidget {
  const _SpecialOffers({required this.popular});

  final AsyncValue<List<Venue>> popular;

  @override
  Widget build(BuildContext context) {
    final venues = popular.valueOrNull ?? const <Venue>[];
    final offers = venues
        .where(
          (v) =>
              (v.offerText.trim().isNotEmpty || v.offerPercent != null) &&
              v.isActive,
        )
        .take(6)
        .toList();
    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrototypeSectionHeader(title: '🏷️ Special offers', onViewAll: null),
          const SizedBox(height: 12),
          _HorizontalList(
            height: 200,
            items: offers
                .map(
                  (v) => SizedBox(
                    width: 260,
                    child: _OfferCard(venue: v),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final discount =
        venue.offerPercent != null
        ? '${venue.offerPercent!.toStringAsFixed(0)}% OFF'
        : 'OFFER';
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.venueDetails.replaceAll(':id', venue.id),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              decoration: BoxDecoration(
                gradient: PrototypeVisuals.thumbGradientFor(venue.id),
              ),
              child: Stack(
                children: [
                  if (venue.coverImageUrl.isNotEmpty)
                    Positioned.fill(child: AppNetworkImage(url: venue.coverImageUrl)),
                  Center(
                    child: Text(
                      PrototypeVisuals.emojiForCategorySlug(
                        venue.category?.slug,
                        icon: venue.category?.icon,
                      ),
                      style: PrototypeVisuals.emojiStyle(fontSize: 40),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        discount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
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
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    venue.offerText.trim().isNotEmpty
                        ? venue.offerText.trim()
                        : 'Limited-time discount on this venue',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                      height: 1.35,
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

/// Horizontal strip of recently-opened venues (in-memory, capped).
class _RecentlyViewed extends ConsumerWidget {
  const _RecentlyViewed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(recentlyViewedIdsProvider);
    if (ids.isEmpty) return const SizedBox.shrink();

    final venues = <Venue>[];
    for (final id in ids) {
      final venue = ref.watch(venueDetailsProvider(id)).valueOrNull;
      if (venue != null) venues.add(venue);
      if (venues.length >= 6) break;
    }
    if (venues.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrototypeSectionHeader(title: '🕘 Recently viewed', onViewAll: null),
          const SizedBox(height: 12),
          _HorizontalList(
            height: 186,
            items: venues
                .map(
                  (v) => SizedBox(
                    width: 250,
                    child: AnimatedEntrance(
                      child: VenueCard(venue: v, compact: true),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/presentation/admin_settings_providers.dart';
import '../../../admin/domain/admin_settings.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/configurable_banner.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../location/presentation/location_providers.dart';
import '../../../location/presentation/widgets/location_bar.dart';
import '../../../location/presentation/widgets/location_picker_sheet.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../domain/context_aware_help.dart';
import '../../domain/customer_section_catalog.dart';
import '../../domain/home_category_catalog.dart';
import '../../domain/category_group.dart';
import '../../domain/bookmyspace_module.dart';
import '../../../ai/domain/voice_locale.dart';
import '../../../../core/modular/feature_id.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/plugins/voice_provider.dart';
import '../../../search/domain/ai_search_intent.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/domain/category_discovery.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../../promotions/presentation/widgets/promotion_strip.dart';
import '../customer_section_providers.dart';
import '../customer_category_preferences_providers.dart';
import '../widgets/category_carousel.dart';
import '../widgets/home_discovery_widgets.dart';

/// The 4 primary sections of BookMySpace
enum MainHomeSection {
  functionHalls,
  lodgeRooms,
  pgHostels,
  institutesClasses;

  String get id {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'function_halls';
      case MainHomeSection.lodgeRooms:
        return 'lodge_rooms';
      case MainHomeSection.pgHostels:
        return 'pg_hostels';
      case MainHomeSection.institutesClasses:
        return 'institutes_classes';
    }
  }

  String get title {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Function Halls';
      case MainHomeSection.lodgeRooms:
        return 'Lodge / Rooms';
      case MainHomeSection.pgHostels:
        return 'PG / Hostels';
      case MainHomeSection.institutesClasses:
        return 'Institutes / Classes';
    }
  }

  String get subtitle {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'Marriage, Convention, Party & Community Halls';
      case MainHomeSection.lodgeRooms:
        return 'Hotels, Lodges, Guest Houses & Hourly Rooms';
      case MainHomeSection.pgHostels:
        return 'Gents, Ladies, Co-Living & Student Hostels';
      case MainHomeSection.institutesClasses:
        return 'Coaching, Tuition, Dance, Music & Sports';
    }
  }

  String get emoji {
    switch (this) {
      case MainHomeSection.functionHalls:
        return '🏛️';
      case MainHomeSection.lodgeRooms:
        return '🏨';
      case MainHomeSection.pgHostels:
        return '🏠';
      case MainHomeSection.institutesClasses:
        return '🎓';
    }
  }

  String get imageUrl {
    switch (this) {
      case MainHomeSection.functionHalls:
        return 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.lodgeRooms:
        return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.pgHostels:
        return 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=900&auto=format&fit=crop&q=80';
      case MainHomeSection.institutesClasses:
        return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=900&auto=format&fit=crop&q=80';
    }
  }

  CustomerSection get catalog =>
      CustomerSection.fromId(id) ?? CustomerSection.functionHalls;

  List<SubCategoryOption> get categoryOptions => catalog.categories
      .map((c) => SubCategoryOption(c.id, c.label, c.emoji))
      .toList();
}

class SubCategoryOption {
  const SubCategoryOption(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

class AmenityFilter {
  const AmenityFilter(this.id, this.label, this.emoji);
  final String id;
  final String label;
  final String emoji;
}

List<AmenityFilter> _amenitiesFor(CustomerSection? section) {
  if (section == null) return const [];
  return CustomerSectionCatalog.amenityFilters(
    section,
  ).map((s) => AmenityFilter(s.id, s.label, s.emoji)).toList();
}

/// Redesigned BookMySpace customer Home Screen:
/// - First Screen: ONLY 4 Main Sections in a fast, responsive, attractive layout
/// - Section Drill-Down: Category Index -> Location -> Search & Voice Booking -> Results -> Direct Booking/Call/WhatsApp
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialSection});

  final CustomerSection? initialSection;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _selectedAmenities = {};

  List<MainHomeSection> _visibleHomeSections(WidgetRef ref) {
    final ids = ref.watch(featureRegistryProvider).visibleHomeSections().toSet();
    final preferences = ref.watch(customerCategoryPreferencesProvider);
    final configured = ref.watch(appCustomerSectionsProvider).valueOrNull ??
        const <AppSectionConfig>[];
    final effective = HomeCategoryCatalog.effectiveMainSections(
      configured: configured,
      featureVisibleIds: ids,
      customerEnabledIds: MainHomeSection.values
          .where((section) => preferences.isEnabled(section.id))
          .map((section) => section.id)
          .toSet(),
    );
    return MainHomeSection.values
        .where((section) => effective.contains(section.catalog))
        .toList();
  }

  List<HomeCategoryItem> _visibleConfiguredHomeCategories(WidgetRef ref) {
    final configured = ref.watch(categoryConfigurationsProvider).valueOrNull;
    final fallback = configured == null || configured.isEmpty
        ? const [
            CategoryConfiguration(
              id: 'lodge_rooms',
              slug: 'lodge_rooms',
              name: 'Stay',
              sectionId: 'lodge_rooms',
              icon: '🏨',
              homeVisible: true,
              sortOrder: 10,
            ),
            CategoryConfiguration(
              id: 'function_halls',
              slug: 'function_halls',
              name: 'Spaces & Events',
              sectionId: 'function_halls',
              icon: '🏛️',
              homeVisible: true,
              sortOrder: 20,
            ),
            CategoryConfiguration(
              id: 'institutes_classes',
              slug: 'institutes_classes',
              name: 'Learning & Classes',
              sectionId: 'institutes_classes',
              icon: '🎓',
              homeVisible: true,
              sortOrder: 30,
            ),
            CategoryConfiguration(
              id: 'pg_hostels',
              slug: 'pg_hostels',
              name: 'PG / Hostels',
              sectionId: 'pg_hostels',
              icon: '🏠',
              homeVisible: true,
              sortOrder: 40,
            ),
          ]
        : configured;
    final preferences = ref.watch(customerCategoryPreferencesProvider);
    final featureVisibleIds = ref
        .watch(featureRegistryProvider)
        .visibleHomeSections()
        .toSet();
    final configuredSections =
        ref.watch(appCustomerSectionsProvider).valueOrNull ??
        const <AppSectionConfig>[];
    final configuredMainIds = HomeCategoryCatalog.effectiveMainSections(
      configured: configuredSections,
      featureVisibleIds: featureVisibleIds,
      customerEnabledIds: MainHomeSection.values
          .where((section) => preferences.isEnabled(section.id))
          .map((section) => section.id)
          .toSet(),
    ).map((section) => section.id).toSet();
    final mainSectionIds = MainHomeSection.values.map((s) => s.id).toSet();
    final groups = CategoryGroup.fromConfigurations(fallback);
    return groups
        .where(
          (group) =>
              !mainSectionIds.contains(group.id) ||
              (featureVisibleIds.contains(group.id) &&
                  (configuredSections.isEmpty ||
                      configuredMainIds.contains(group.id))),
        )
        .where((group) => preferences.isEnabled(group.id))
        .map(
          (group) => HomeCategoryItem(
            CategoryConfiguration(
              id: group.id,
              slug: group.slug,
              name: group.name,
              icon: group.icon,
              sectionId: group.id,
              sortOrder: group.sortOrder,
              homeVisible: group.isActive,
            ),
          ),
        )
        .toList(growable: false);
  }

  void _openConfiguredHomeCategory(HomeCategoryItem item) {
    final section = CustomerSection.fromId(
      item.sectionId.isNotEmpty ? item.sectionId : item.configuration.slug,
    );
    if (section != null) {
      selectCustomerSection(ref, section);
    } else {
      context.push(AppRoutes.search);
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSection;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        selectCustomerSection(ref, initial);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final selectedCatalog = ref.watch(selectedCustomerSectionProvider);
    final selectedCategorySlug = ref.watch(selectedCustomerCategoryProvider);
    // Do not query venue data while the modular Home catalog is being shown.
    // Category-scoped data is resolved by the selected module only.
    final popularVenuesAsync = selectedCatalog == null
        ? const AsyncValue.data(<Venue>[])
        : ref.watch(
            moduleVenuesProvider(
              selectedCategorySlug == null || selectedCategorySlug == 'all'
                  ? selectedCatalog.id
                  : selectedCategorySlug,
            ),
          );
    final area = ref.watch(searchAreaProvider);
    final features = ref.watch(featureRegistryProvider);
    final adminSettings =
        ref.watch(adminSettingsProvider).valueOrNull ?? AdminSettings.defaults;
    final homeConfig = adminSettings.home;
    final selectedSection = selectedCatalog == null
        ? null
        : MainHomeSection.values.firstWhere(
            (s) => s.id == selectedCatalog.id,
            orElse: () => MainHomeSection.functionHalls,
          );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ResponsiveLayoutBuilder(
          builder: (context, responsive) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(popularVenuesProvider);
                ref.invalidate(nearbyVenuesProvider);
                ref.invalidate(venueCategoriesProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Top App Bar
                  SliverToBoxAdapter(
                    child: _TopHeaderBar(
                      user: user,
                      responsive: responsive,
                      showAssistant: features.isExposed(FeatureId.ai),
                      showNotifications: features.isExposed(
                        FeatureId.notifications,
                      ),
                      showCheckIn: features.isQrVisible(),
                      onLoginTap: () => context.push(AppRoutes.login),
                      onProfileTap: () => context.push(AppRoutes.profile),
                      onNotificationsTap: () =>
                          context.push(AppRoutes.notifications),
                      onAssistantTap: () => context.push(AppRoutes.assistant),
                      onCheckInTap: () => context.push(AppRoutes.checkIn),
                    ),
                  ),
                  if (AdminSettings.flag(
                    homeConfig['home_banner_visible'],
                    fallback: true,
                  ))
                    const SliverToBoxAdapter(child: PromotionStrip()),
                  if (AdminSettings.flag(
                    homeConfig['home_banner_visible'],
                    fallback: true,
                  ))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: ConfigurableBanner(settings: homeConfig),
                      ),
                    ),

                  // =========================================================
                  // 🌟 FIRST SCREEN: EXACTLY 4 MAIN SECTIONS ONLY
                  // =========================================================
                  if (selectedSection == null) ...[
                    if (responsive.isCompact)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.horizontalPadding,
                          ),
                          child: LocationBar(
                            area: area,
                            dense: true,
                            onTap: _showLocationPickerModal,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AdminSettings.text(
                                homeConfig['hero_title'],
                                'Book Your Space',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AdminSettings.text(
                                homeConfig['hero_subtitle'],
                                'Select what you are looking for to get started:',
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          responsive.horizontalPadding,
                          16,
                          responsive.horizontalPadding,
                          0,
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (features.isExposed(FeatureId.events))
                              ActionChip(
                                avatar: const Icon(
                                  Icons.event_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.events),
                                onPressed: () =>
                                    context.push(AppRoutes.eventsList),
                              ),
                            if (features.isExposed(FeatureId.courses))
                              ActionChip(
                                avatar: const Icon(
                                  Icons.school_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.courses),
                                onPressed: () =>
                                    context.push(AppRoutes.coursesList),
                              ),
                            if (features.isExposed(FeatureId.maps))
                              ActionChip(
                                avatar: const Icon(
                                  Icons.map_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.viewOnMap),
                                onPressed: () => context.push(AppRoutes.map),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (responsive.isCompact)
                      SliverToBoxAdapter(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final cardWidth = (width * 0.61).clamp(
                              200.0,
                              280.0,
                            );
                            final cardHeight = (width * 0.38).clamp(
                              148.0,
                              180.0,
                            );
                            return SizedBox(
                              height: cardHeight,
                              child: ListView.separated(
                                clipBehavior: Clip.none,
                                padding: EdgeInsets.symmetric(
                                  horizontal: responsive.horizontalPadding,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: _visibleConfiguredHomeCategories(
                                  ref,
                                ).length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(width: responsive.gridSpacing),
                                itemBuilder: (context, index) {
                                  final section =
                                      _visibleConfiguredHomeCategories(
                                        ref,
                                      )[index];
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _MainSectionHeroCard(
                                      key: ValueKey('section_${section.id}'),
                                      category: section,
                                      isTabletOrWide: false,
                                      onTap: () =>
                                          _openConfiguredHomeCategory(section),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: responsive.categoryColumns,
                                mainAxisSpacing: responsive.gridSpacing,
                                crossAxisSpacing: responsive.gridSpacing,
                                childAspectRatio:
                                    responsive.categoryAspectRatio,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final visible = _visibleConfiguredHomeCategories(
                                ref,
                              );
                              final section = visible[index];
                              return _MainSectionHeroCard(
                                key: ValueKey('section_${section.id}'),
                                category: section,
                                isTabletOrWide: responsive.isTabletOrLandscape,
                                onTap: () =>
                                    _openConfiguredHomeCategory(section),
                              );
                            },
                            childCount: _visibleConfiguredHomeCategories(
                              ref,
                            ).length,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: const HomePromoCard(),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 16,
                        ),
                        child: HomeRadarCard(
                          locationLabel: area.label,
                          verifiedCount: popularVenuesAsync.maybeWhen(
                            data: (venues) => venues.length,
                            orElse: () => 0,
                          ),
                          onTap: _showLocationPickerModal,
                        ),
                      ),
                    ),

                    // Location bar at bottom of first screen
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 24,
                        ),
                        child: LocationFooterCard(
                          area: area,
                          onTap: _showLocationPickerModal,
                        ),
                      ),
                    ),
                  ]
                  // =========================================================
                  // 🚀 SECTION DRILL-DOWN: Category Index -> Location -> Results
                  // =========================================================
                  else ...[
                    // Section Back & Title Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      clearCustomerSection(ref);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'All Spaces',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            selectedSection.emoji,
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              selectedSection.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: theme
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${selectedSection.emoji} ${selectedSection.title}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              selectedSection.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Location selector
                            LocationBar(
                              area: area,
                              onTap: _showLocationPickerModal,
                            ),
                            const SizedBox(height: 8),
                            CategorySpotlightCard(
                              title: selectedSection.title,
                              imageUrl: selectedSection.imageUrl,
                              onTap: () => context.push(AppRoutes.search),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () =>
                                  _showContextAwareHelpDialog(context),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.help_outline_rounded,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedSection.catalog.isBookable
                                          ? 'Help · How ${selectedSection.title} booking works'
                                          : 'Help · How institute enquiries work',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 1. Relevant Index / Categories (Horizontal Row)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.horizontalPadding,
                              vertical: 4,
                            ),
                            child: Text(
                              'Choose Category',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          CategoryCarousel(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.horizontalPadding,
                            ),
                            selectedId: selectedCategorySlug,
                            onSelected: (id) {
                              ref
                                      .read(
                                        selectedCustomerCategoryProvider
                                            .notifier,
                                      )
                                      .state =
                                  id;
                            },
                            items: _carouselCategories(
                              selectedSection,
                              ref
                                      .watch(categoryConfigurationsProvider)
                                      .valueOrNull ??
                                  const [],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Search & Voice Booking & Quick Book Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            // Search Bar
                            InkWell(
                              onTap: () {
                                context.push(
                                  AppRoutes.search,
                                  extra: {
                                    'section': selectedSection.id,
                                    'category': selectedCategorySlug == 'all'
                                        ? null
                                        : selectedCategorySlug,
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Search ${selectedSection.title} in ${area.label}...',
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color:
                                            theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.tune_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (selectedSection.catalog.isBookable) ...[
                              if (features.isExposed(FeatureId.voice)) ...[
                                _VoiceBookingBanner(
                                  onTap: () => _showVoiceBookingDialog(context),
                                ),
                                const SizedBox(height: 10),
                              ],
                              _QuickBookCard(
                                sectionTitle: selectedSection.title,
                                ctaLabel: AdminSettings.text(
                                  homeConfig['primary_booking_button_text'],
                                  'Book',
                                ),
                                onQuickBookTap: () {
                                  final match = _scopedVenues(
                                    popularVenuesAsync.value ?? const [],
                                  ).firstOrNull;
                                  if (match == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No verified ${selectedSection.title} available right now.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  context.push(
                                    AppRoutes.bookingFlow.replaceAll(
                                      ':id',
                                      match.id,
                                    ),
                                    extra: match,
                                  );
                                },
                              ),
                            ] else
                              _InstituteEnquiryCard(
                                onTap: () => context.push(
                                  AppRoutes.search,
                                  extra: <String, dynamic>{
                                    'section':
                                        CustomerSection.institutesClasses.id,
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Amenity Filter Chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Filter by Amenities',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_selectedAmenities.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAmenities.clear();
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Clear Filters'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 48,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: _amenitiesFor(
                                  selectedSection.catalog,
                                ).length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final amenity = _amenitiesFor(
                                    selectedSection.catalog,
                                  )[index];
                                  final isSelected = _selectedAmenities
                                      .contains(amenity.id);
                                  return FilterChip(
                                    selected: isSelected,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedAmenities.add(amenity.id);
                                        } else {
                                          _selectedAmenities.remove(amenity.id);
                                        }
                                      });
                                    },
                                    avatar: Text(
                                      amenity.emoji,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    label: Text(
                                      amenity.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    selectedColor:
                                        theme.colorScheme.primaryContainer,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Available Spaces',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // 4. Venues List / Grid in Responsive Layout
                    popularVenuesAsync.when(
                      data: (venues) {
                        final scoped = _scopedVenues(venues);
                        if (scoped.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No spaces found',
                                message:
                                    'Try changing category or location filters.',
                              ),
                            ),
                          );
                        }

                        final listPadding = EdgeInsets.symmetric(
                          horizontal: responsive.horizontalPadding,
                          vertical: 8,
                        );
                        final bookable = selectedSection.catalog.isBookable;
                        // HotelStyleVenueCard is compact and sizes itself.
                        // A fixed-aspect SliverGrid leaves a large empty
                        // gap under each lodge card on compact Android.
                        if (selectedSection == MainHomeSection.lodgeRooms) {
                          return SliverPadding(
                            padding: listPadding,
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final venue = scoped[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: responsive.gridSpacing,
                                  ),
                                  child: HotelStyleVenueCard(
                                    venue: venue,
                                    onTap: () => context.push(
                                      AppRoutes.venueDetails.replaceAll(
                                        ':id',
                                        venue.id,
                                      ),
                                    ),
                                    onBookTap: bookable
                                        ? () => context.push(
                                            AppRoutes.bookingFlow.replaceAll(
                                              ':id',
                                              venue.id,
                                            ),
                                            extra: venue,
                                          )
                                        : () => _handleCall(context, venue),
                                  ),
                                );
                              }, childCount: scoped.length),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: listPadding,
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: responsive.resultsColumns,
                                  mainAxisSpacing: responsive.gridSpacing,
                                  crossAxisSpacing: responsive.gridSpacing,
                                  childAspectRatio:
                                      responsive.resultsAspectRatio,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final venue = scoped[index];
                              return _SectionVenueCard(
                                venue: venue,
                                bookLabel: AdminSettings.text(
                                  homeConfig['primary_booking_button_text'],
                                  CustomerSectionCatalog.bookingCtaLabel(
                                    selectedSection.catalog,
                                  ),
                                ),
                                onTap: () => context.push(
                                  AppRoutes.venueDetails.replaceAll(
                                    ':id',
                                    venue.id,
                                  ),
                                ),
                                onBookTap: bookable
                                    ? () => context.push(
                                        AppRoutes.bookingFlow.replaceAll(
                                          ':id',
                                          venue.id,
                                        ),
                                        extra: venue,
                                      )
                                    : () => _handleCall(context, venue),
                                onCallTap: () => _handleCall(context, venue),
                                onWhatsAppTap: () =>
                                    _handleWhatsApp(context, venue),
                              );
                            }, childCount: scoped.length),
                          ),
                        );
                      },
                      loading: () => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(responsive.horizontalPadding),
                          child: const Row(
                            children: [
                              Expanded(
                                child: SkeletonBox(height: 220, radius: 16),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: SkeletonBox(height: 220, radius: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      error: (err, _) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorView(
                            message: err.toString(),
                            onRetry: () {
                              if (selectedCatalog == null) {
                                ref.invalidate(popularVenuesProvider);
                              } else {
                                ref.invalidate(
                                  moduleVenuesProvider(
                                    selectedCategorySlug == null ||
                                            selectedCategorySlug == 'all'
                                        ? selectedCatalog.id
                                        : selectedCategorySlug,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Venues matching the active section, category, amenities and the
  List<CategoryConfiguration> _carouselCategories(
    MainHomeSection selectedSection,
    List<CategoryConfiguration> db,
  ) {
    final sectionId = selectedSection.catalog.id;
    return CategoryDiscovery.homeChips(
      db,
      sectionId: sectionId,
      fallback: [
        for (final cat in selectedSection.categoryOptions)
          CategoryConfiguration(
            id: cat.id,
            slug: cat.id,
            name: cat.label,
            icon: cat.emoji,
            sectionId: sectionId,
          ),
      ],
    );
  }

  /// selected search area (distance within radius, when coordinates exist).
  List<Venue> _scopedVenues(List<Venue> venues) {
    final catalog = ref.read(selectedCustomerSectionProvider);
    if (catalog == null) return const [];
    final categorySlug = ref.read(selectedCustomerCategoryProvider);
    final area = ref.read(searchAreaProvider);
    final point = LatLng(area.latitude, area.longitude);
    const distance = Distance();
    return venues
        .where(
          (v) =>
              CustomerSectionCatalog.matchesVenue(v, catalog, categorySlug) &&
              CustomerSectionCatalog.matchesAmenities(v, _selectedAmenities),
        )
        .map((v) {
          final d = distance(point, LatLng(v.latitude, v.longitude));
          return v.copyWith(distanceKm: d / 1000);
        })
        .where((v) => (v.distanceKm ?? 0) <= area.radiusKm)
        .toList();
  }

  Future<void> _showLocationPickerModal() async {
    final area = await LocationPickerSheet.show(
      context,
      initial: ref.read(searchAreaProvider),
    );
    if (area == null || !mounted) return;
    ref.read(searchAreaProvider.notifier).state = area;
  }

  // Retained as the simple Help fallback for callers that do not need chat.
  // ignore: unused_element
  void _showHelpDialog(BuildContext context) {
    final section = ref.read(selectedCustomerSectionProvider);
    final title = section?.title ?? 'BookMySpace';
    final steps = switch (section) {
      CustomerSection.functionHalls => [
        '1. Pick your event date and guest count in the filters.',
        '2. Compare halls by price, parking, catering, AC and generator.',
        '3. Select a time slot, pay a small advance and confirm instantly.',
        '4. Owner contact unlocks automatically after your confirmed payment.',
      ],
      CustomerSection.lodgeRooms => [
        '1. Choose check-in / check-out dates and your room type.',
        '2. Compare stays by rating and price per night.',
        '3. Book your stay and pay the advance to confirm.',
        '4. Owner contact unlocks automatically after your confirmed payment.',
      ],
      CustomerSection.pgHostels => [
        '1. Filter by gender, sharing and food preference.',
        '2. Compare rent per month and security deposit.',
        '3. Reserve your bed with a small advance payment.',
        '4. Owner contact unlocks automatically after your confirmed payment.',
      ],
      CustomerSection.institutesClasses => [
        '1. Filter by class type (coaching, computer, dance, music, sports).',
        '2. Check the mode (online / offline / hybrid) and course fee.',
        '3. Institutes are listing-only — call or WhatsApp the academy directly.',
      ],
      _ => [
        'Select a section, set your location and search radius, then filter by what matters to you.',
      ],
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Help · $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(step, style: const TextStyle(fontSize: 13.5)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showContextAwareHelpDialog(BuildContext context) {
    final section = ref.read(selectedCustomerSectionProvider);
    final area = ref.read(searchAreaProvider);
    final controller = TextEditingController();
    var reply = ContextAwareHelp.answer(section: section, question: '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('AI Help · ${section?.title ?? 'BookMySpace'}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply.message),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => setState(() {
                    reply = ContextAwareHelp.answer(
                      section: section,
                      question: controller.text,
                      location: area.label,
                    );
                  }),
                  decoration: InputDecoration(
                    labelText: AdminSettings.text(
                      AdminSettings.defaults.home['search_placeholder'],
                      'Search hotels, PGs, venues...',
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (reply.action != null)
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  final action = reply.action;
                  if (action == HelpAction.booking && section != null) {
                    final match = _scopedVenues(
                      ref.read(popularVenuesProvider).asData?.value ?? const [],
                    ).firstOrNull;
                    if (match != null) {
                      context.push(
                        AppRoutes.bookingFlow.replaceAll(':id', match.id),
                        extra: match,
                      );
                    } else {
                      context.push(
                        AppRoutes.search,
                        extra: {'section': section.id},
                      );
                    }
                  } else if (action == HelpAction.instituteEnquiry ||
                      action == HelpAction.search) {
                    if (section != null) {
                      context.push(
                        AppRoutes.search,
                        extra: {'section': section.id},
                      );
                    }
                  }
                },
                child: Text(
                  reply.action == HelpAction.booking ? 'Continue' : 'Search',
                ),
              ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showVoiceBookingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Text(
                '🎙️ Bol-ke-Book',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Speak in English, Telugu, or Hindi to find and book spaces instantly.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, size: 36, color: AppTheme.brand),
              ),
              const SizedBox(height: 16),
              const Text(
                'Try saying: "Find marriage halls in Hyderabad with parking for 500 guests"',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final section = ref.read(selectedCustomerSectionProvider);
                final aliases = ref.read(categoryAliasIndexProvider);
                final voice = resolvedVoiceProvider(
                  ref.read(providerRegistryProvider),
                );
                if (voice == null) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Voice is unavailable. Use normal search instead.',
                        ),
                      ),
                    );
                    context.push(
                      AppRoutes.search,
                      extra: {if (section != null) 'section': section.id},
                    );
                  }
                  return;
                }
                try {
                  await voice.ensureInitialized();
                } catch (_) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Voice is unavailable. Use normal search instead.',
                        ),
                      ),
                    );
                    context.push(
                      AppRoutes.search,
                      extra: {if (section != null) 'section': section.id},
                    );
                  }
                  return;
                }
                String transcript = '';
                await voice.listen(
                  localeId: VoiceLocale.speechId(
                    Localizations.localeOf(context),
                  ),
                  onResult: (words) => transcript = words,
                );
                await Future<void>.delayed(const Duration(seconds: 5));
                await voice.stop();
                if (!context.mounted) return;
                Navigator.pop(context);
                final intent = AiSearchIntent.parse(
                  transcript,
                  selectedSection: section,
                  aliases: aliases,
                );
                final selectedCategory = ref.read(
                  selectedCustomerCategoryProvider,
                );
                context.push(
                  AppRoutes.search,
                  extra: {
                    'section': intent.section?.id ?? section?.id,
                    'query': transcript,
                    'intent': intent,
                    'category':
                        intent.categorySlug ??
                        (selectedCategory == 'all' ? null : selectedCategory),
                  },
                );
              },
              child: const Text('Start Listening'),
            ),
          ],
        );
      },
    );
  }

  bool _hasConfirmedPaidBooking(String venueId) {
    final bookings = ref.read(myBookingsProvider).asData?.value ?? const [];
    return bookings.any(
      (b) =>
          b.venueId == venueId &&
          (b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.completed),
    );
  }

  void _handleCall(BuildContext context, Venue venue) {
    final section = CustomerSectionCatalog.sectionForVenue(venue);
    final allowed = CustomerSectionCatalog.canRevealOwnerContact(
      section: section,
      hasConfirmedPaidBooking: _hasConfirmedPaidBooking(venue.id),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? 'Calling ${venue.name}...'
              : 'Owner number unlocks after confirmed advance payment.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleWhatsApp(BuildContext context, Venue venue) {
    final section = CustomerSectionCatalog.sectionForVenue(venue);
    final allowed = CustomerSectionCatalog.canRevealOwnerContact(
      section: section,
      hasConfirmedPaidBooking: _hasConfirmedPaidBooking(venue.id),
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Owner WhatsApp unlocks after confirmed advance payment.',
          ),
        ),
      );
      return;
    }
    final phone = venue.contactWhatsapp;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp contact is unavailable.')),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://api.whatsapp.com/send?phone=$cleanPhone&text='
      '${Uri.encodeComponent('Hi! I am interested in ${venue.name} on BookMySpace.')}',
    );
    launchUrl(uri, mode: LaunchMode.externalApplication).then((launched) {
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    });
  }
}

/// Header Bar with Logo and Profile Actions
class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.user,
    required this.responsive,
    required this.showAssistant,
    required this.showNotifications,
    this.showCheckIn = true,
    required this.onLoginTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onAssistantTap,
    required this.onCheckInTap,
  });

  final dynamic user;
  final ResponsiveInfo responsive;
  final bool showAssistant;
  final bool showNotifications;
  final bool showCheckIn;
  final VoidCallback onLoginTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onCheckInTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: 12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.brand, Color(0xFF757DE8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.domain_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'BookMySpace',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: AppTheme.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.62,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user == null)
                        FilledButton.tonalIcon(
                          onPressed: onLoginTap,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: onProfileTap,
                          borderRadius: BorderRadius.circular(24),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              () {
                                final email = user?.email as String?;
                                if (email == null || email.isEmpty) return 'U';
                                return email[0].toUpperCase();
                              }(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      if (showAssistant)
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(48, 48),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: onAssistantTap,
                          icon: const Icon(Icons.auto_awesome, size: 22),
                        ),
                      if (showCheckIn)
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(48, 48),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: onCheckInTap,
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 22,
                          ),
                        ),
                      if (showNotifications)
                        IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(48, 48),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: onNotificationsTap,
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Large, eye-catching, extremely simple Hero Card for the 4 Main Sections on the first screen.
/// Adapts dynamically on phone single-column, tablet 2-column, and extra-wide landscape 4-column layouts.
class _MainSectionHeroCard extends StatelessWidget {
  const _MainSectionHeroCard({
    super.key,
    required this.category,
    required this.isTabletOrWide,
    required this.onTap,
  });

  final HomeCategoryItem category;
  final bool isTabletOrWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTabletOrWide ? 22 : 18),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            AppNetworkImage(
              url: category.configuration.imageUrl,
              fit: BoxFit.cover,
            ),

            // High-Contrast Gradient Scrim
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.90),
                    Colors.black.withValues(alpha: 0.74),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTabletOrWide ? 18 : 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Emoji Badge
                  Container(
                    width: isTabletOrWide ? 56 : 48,
                    height: isTabletOrWide ? 56 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category.configuration.icon.isNotEmpty
                          ? category.configuration.icon
                          : '✨',
                      style: TextStyle(fontSize: isTabletOrWide ? 28 : 24),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category.title,
                          style: TextStyle(
                            fontSize: isTabletOrWide ? 18 : 16.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          category.configuration.sectionId.isNotEmpty
                              ? (CustomerSection.fromId(
                                      category.configuration.sectionId,
                                    )?.subtitle ??
                                    'Explore available spaces near you')
                              : 'Explore available spaces near you',
                          style: TextStyle(
                            fontSize: isTabletOrWide ? 12 : 11.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Circular Action Arrow
                  Container(
                    width: isTabletOrWide ? 42 : 36,
                    height: isTabletOrWide ? 42 : 36,
                    decoration: const BoxDecoration(
                      color: AppTheme.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
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

/// Voice Booking Banner
class _VoiceBookingBanner extends StatelessWidget {
  const _VoiceBookingBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF283593), Color(0xFF3F51B5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brand.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎙️ Bol-ke-Book (Voice Search)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Tap to speak and book in Telugu, Hindi or English',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstituteEnquiryCard extends StatelessWidget {
  const _InstituteEnquiryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.contact_phone_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Explore institutes and contact them by Call or WhatsApp.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Explore'),
          ),
        ],
      ),
    );
  }
}

/// Quick 1-Tap Booking Card
class _QuickBookCard extends StatelessWidget {
  const _QuickBookCard({
    required this.sectionTitle,
    required this.onQuickBookTap,
    required this.ctaLabel,
  });

  final String sectionTitle;
  final VoidCallback onQuickBookTap;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('⚡', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1-Tap Fast Booking',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Instant confirmation for top-rated $sectionTitle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onQuickBookTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              ctaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Venue / Space Result Card with Direct Book, Call, and WhatsApp Buttons
class _SectionVenueCard extends StatelessWidget {
  const _SectionVenueCard({
    required this.venue,
    required this.onTap,
    required this.onBookTap,
    required this.onCallTap,
    required this.onWhatsAppTap,
    this.bookLabel = 'Book Now',
  });

  final Venue venue;
  final VoidCallback onTap;
  final VoidCallback onBookTap;
  final VoidCallback onCallTap;
  final VoidCallback onWhatsAppTap;
  final String bookLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
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
            // Venue Cover Image & Badges
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
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: RatingBadge(
                          rating: venue.avgRating,
                          count: venue.ratingCount,
                        ),
                      ),
                    ),
                  if (venue.distanceKm != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatDistance(venue.distanceKm),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Venue Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.addressLine1.isNotEmpty ? venue.addressLine1 : venue.city}, ${venue.city}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Pricing & Capacity
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${venue.pricingBaseAmount.toInt()}/day',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (venue.capacity > 0)
                        Flexible(
                          child: Text(
                            '👥 ${venue.capacity} Guests',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons: Book Now, Call, WhatsApp
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: onBookTap,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            bookLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        onPressed: onCallTap,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: onWhatsAppTap,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Text('💬', style: TextStyle(fontSize: 14)),
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

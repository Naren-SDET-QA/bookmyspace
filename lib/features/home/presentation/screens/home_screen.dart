import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';

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

  List<SubCategoryOption> get categoryOptions {
    switch (this) {
      case MainHomeSection.functionHalls:
        return const [
          SubCategoryOption('all', 'All Halls', '🏛️'),
          SubCategoryOption('marriage_hall', 'Marriage Hall', '💍'),
          SubCategoryOption('convention_center', 'Convention Hall', '🏢'),
          SubCategoryOption('party_hall', 'Party Hall', '🎉'),
          SubCategoryOption('community_hall', 'Community Hall', '👥'),
          SubCategoryOption('govt_hall', 'Govt Hall', '🏛️'),
          SubCategoryOption('auditorium', 'Auditorium', '🎭'),
        ];
      case MainHomeSection.lodgeRooms:
        return const [
          SubCategoryOption('all', 'All Rooms', '🏨'),
          SubCategoryOption('hotel', 'Hotel', '🛎️'),
          SubCategoryOption('lodge', 'Lodge', '🛏️'),
          SubCategoryOption('guest_house', 'Guest House', '🏡'),
          SubCategoryOption('homestay', 'Homestay', '🌿'),
          SubCategoryOption('resort', 'Resort', '🌴'),
          SubCategoryOption('hourly_room', 'Hourly Room', '⏱️'),
        ];
      case MainHomeSection.pgHostels:
        return const [
          SubCategoryOption('all', 'All PGs', '🏠'),
          SubCategoryOption('gents_pg', 'Gents PG', '👨'),
          SubCategoryOption('ladies_pg', 'Ladies PG', '👩'),
          SubCategoryOption('student_hostel', 'Student Hostel', '🎒'),
          SubCategoryOption('coliving', 'Co-Living', '🛋️'),
          SubCategoryOption('working_men', 'Working Men', '💼'),
          SubCategoryOption('working_women', 'Working Women', '👩‍💼'),
        ];
      case MainHomeSection.institutesClasses:
        return const [
          SubCategoryOption('all', 'All Classes', '🎓'),
          SubCategoryOption('coaching', 'Coaching', '📚'),
          SubCategoryOption('tuition', 'Tuition', '✏️'),
          SubCategoryOption('computer', 'Computer / IT', '💻'),
          SubCategoryOption('dance', 'Dance Academy', '💃'),
          SubCategoryOption('music', 'Music School', '🎵'),
          SubCategoryOption('sports', 'Sports & Gym', '⚽'),
        ];
    }
  }
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

const _homeAmenities = [
  AmenityFilter('wifi', 'WiFi', '📶'),
  AmenityFilter('ac', 'Air Conditioned', '❄️'),
  AmenityFilter('parking', 'Parking', '🚗'),
  AmenityFilter('food', 'Food / Catering', '🍽️'),
  AmenityFilter('generator', 'Power Backup', '⚡'),
  AmenityFilter('cctv', 'CCTV Security', '📹'),
  AmenityFilter('lift', 'Elevator', '🛗'),
];

/// Redesigned BookMySpace customer Home Screen:
/// - First Screen: ONLY 4 Main Sections in a fast, responsive, attractive layout
/// - Section Drill-Down: Category Index -> Location -> Search & Voice Booking -> Results -> Direct Booking/Call/WhatsApp
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MainHomeSection? _selectedSection;
  String _selectedCategorySlug = 'all';
  String _currentLocation = 'Hyderabad (Madhapur)';
  String _searchRadius = 'Within 10 km';
  final Set<String> _selectedAmenities = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final popularVenuesAsync = ref.watch(popularVenuesProvider);

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
                      onLoginTap: () => context.push(AppRoutes.login),
                      onProfileTap: () => context.push(AppRoutes.profile),
                      onNotificationsTap: () => context.push(AppRoutes.notifications),
                    ),
                  ),

                  // =========================================================
                  // 🌟 FIRST SCREEN: EXACTLY 4 MAIN SECTIONS ONLY
                  // =========================================================
                  if (_selectedSection == null) ...[
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
                              'Book Your Space',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select what you are looking for to get started:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Dynamic Aspect Ratio Responsive Grid for the 4 Main Sections
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.horizontalPadding,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: responsive.categoryColumns,
                          mainAxisSpacing: responsive.gridSpacing,
                          crossAxisSpacing: responsive.gridSpacing,
                          childAspectRatio: responsive.categoryAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final section = MainHomeSection.values[index];
                            return _MainSectionHeroCard(
                              section: section,
                              isTabletOrWide: responsive.isTabletOrLandscape,
                              onTap: () {
                                setState(() {
                                  _selectedSection = section;
                                  _selectedCategorySlug = 'all';
                                });
                              },
                            );
                          },
                          childCount: MainHomeSection.values.length,
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
                        child: _LocationFooterCard(
                          currentLocation: _currentLocation,
                          searchRadius: _searchRadius,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSection = null;
                                      _selectedCategorySlug = 'all';
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(120, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  label: const Text(
                                    'All Spaces',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_selectedSection!.emoji, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _selectedSection!.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_selectedSection!.emoji} ${_selectedSection!.title}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _selectedSection!.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Location selector
                            _LocationSelectorBar(
                              location: _currentLocation,
                              radius: _searchRadius,
                              onTap: _showLocationPickerModal,
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
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(
                                horizontal: responsive.horizontalPadding,
                              ),
                              itemCount: _selectedSection!.categoryOptions.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final cat = _selectedSection!.categoryOptions[index];
                                final isSelected = _selectedCategorySlug == cat.id;
                                return FilterChip(
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategorySlug = cat.id;
                                    });
                                  },
                                  avatar: Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                                  label: Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  selectedColor: theme.colorScheme.primary,
                                  checkmarkColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                );
                              },
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
                                    'category': _selectedCategorySlug == 'all'
                                        ? _selectedSection!.id
                                        : _selectedCategorySlug,
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
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                                        'Search ${_selectedSection!.title} in $_currentLocation...',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
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

                            // Voice Booking Banner
                            _VoiceBookingBanner(
                              onTap: () => _showVoiceBookingDialog(context),
                            ),
                            const SizedBox(height: 10),

                            // 1-Tap Quick Book Card
                            _QuickBookCard(
                              sectionTitle: _selectedSection!.title,
                              onQuickBookTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Finding fastest verified ${_selectedSection!.title}...'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Filter by Amenities',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_selectedAmenities.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedAmenities.clear();
                                      });
                                    },
                                    child: const Text('Clear Filters'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 38,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _homeAmenities.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final amenity = _homeAmenities[index];
                                  final isSelected = _selectedAmenities.contains(amenity.id);
                                  return FilterChip(
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedAmenities.add(amenity.id);
                                        } else {
                                          _selectedAmenities.remove(amenity.id);
                                        }
                                      });
                                    },
                                    avatar: Text(amenity.emoji, style: const TextStyle(fontSize: 12)),
                                    label: Text(amenity.label, style: const TextStyle(fontSize: 12)),
                                    selectedColor: theme.colorScheme.primaryContainer,
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
                        if (venues.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No spaces found',
                                message: 'Try changing category or location filters.',
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.horizontalPadding,
                            vertical: 8,
                          ),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: responsive.resultsColumns,
                              mainAxisSpacing: responsive.gridSpacing,
                              crossAxisSpacing: responsive.gridSpacing,
                              childAspectRatio: responsive.resultsAspectRatio,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final venue = venues[index % venues.length];
                                return _SectionVenueCard(
                                  venue: venue,
                                  onTap: () => context.push(
                                    AppRoutes.venueDetails.replaceAll(':id', venue.id),
                                  ),
                                  onBookTap: () => context.push(
                                    AppRoutes.bookingFlow.replaceAll(':id', venue.id),
                                  ),
                                  onCallTap: () => _handleCall(context, venue),
                                  onWhatsAppTap: () => _handleWhatsApp(context, venue),
                                );
                              },
                              childCount: venues.length,
                            ),
                          ),
                        );
                      },
                      loading: () => SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(responsive.horizontalPadding),
                          child: const Row(
                            children: [
                              Expanded(child: SkeletonBox(height: 220, radius: 16)),
                              SizedBox(width: 12),
                              Expanded(child: SkeletonBox(height: 220, radius: 16)),
                            ],
                          ),
                        ),
                      ),
                      error: (err, _) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorView(
                            message: err.toString(),
                            onRetry: () => ref.invalidate(popularVenuesProvider),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 48),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLocationPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final cities = [
          'Hyderabad (Madhapur / Hitec City)',
          'Hyderabad (Gachibowli)',
          'Hyderabad (Kukatpally)',
          'Hyderabad (Secunderabad)',
          'Bengaluru (Koramangala)',
          'Bengaluru (Whitefield)',
          'Mumbai (Andheri)',
          'Delhi NCR (Cyber Hub)',
        ];
        final radii = ['Within 5 km', 'Within 10 km', 'Within 25 km', 'Entire City'];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Location & Search Area',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Search Radius:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: radii.map((r) {
                    final isSelected = _searchRadius == r;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(r),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _searchRadius = r);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Popular Areas:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...cities.map((city) {
                  final isSelected = _currentLocation.contains(city.split(' ')[0]);
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(city),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.brand) : null,
                    onTap: () {
                      setState(() => _currentLocation = city);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceBookingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🎙️ Bol-ke-Book', style: TextStyle(fontWeight: FontWeight.bold)),
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
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing voice request...')),
                );
              },
              child: const Text('Start Listening'),
            ),
          ],
        );
      },
    );
  }

  void _handleCall(BuildContext context, Venue venue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${venue.name} contact desk...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleWhatsApp(BuildContext context, Venue venue) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening WhatsApp chat with ${venue.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Header Bar with Logo and Profile Actions
class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.user,
    required this.responsive,
    required this.onLoginTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final dynamic user;
  final ResponsiveInfo responsive;
  final VoidCallback onLoginTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.horizontalPadding,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Text(
                'BookMySpace',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppTheme.brand,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (user == null)
                FilledButton.tonalIcon(
                  onPressed: onLoginTap,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(80, 40),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              else
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      user?.email?.isNotEmpty == true ? user.email[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onNotificationsTap,
                icon: const Icon(Icons.notifications_none_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Large, eye-catching, extremely simple Hero Card for the 4 Main Sections on the first screen.
/// Adapts dynamically on phone single-column, tablet 2-column, and extra-wide landscape 4-column layouts.
class _MainSectionHeroCard extends StatelessWidget {
  const _MainSectionHeroCard({
    required this.section,
    required this.isTabletOrWide,
    required this.onTap,
  });

  final MainHomeSection section;
  final bool isTabletOrWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTabletOrWide ? 22 : 18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            AppNetworkImage(
              url: section.imageUrl,
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
                      section.emoji,
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
                          section.title,
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
                          section.subtitle,
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

/// Location Footer Card at the bottom of the first screen
class _LocationFooterCard extends StatelessWidget {
  const _LocationFooterCard({
    required this.currentLocation,
    required this.searchRadius,
    required this.onTap,
  });

  final String currentLocation;
  final String searchRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Text('📍', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current City: $currentLocation',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Tap to change search area ($searchRadius)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_location_alt_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Location Selector Bar inside Section Drill-Down
class _LocationSelectorBar extends StatelessWidget {
  const _LocationSelectorBar({
    required this.location,
    required this.radius,
    required this.onTap,
  });

  final String location;
  final String radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$location • $radius',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Change',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.primary,
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
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎙️ Bol-ke-Book (Voice Search)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Tap to speak and book in Telugu, Hindi or English',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Quick 1-Tap Booking Card
class _QuickBookCard extends StatelessWidget {
  const _QuickBookCard({
    required this.sectionTitle,
    required this.onQuickBookTap,
  });

  final String sectionTitle;
  final VoidCallback onQuickBookTap;

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Instant confirmation for top-rated $sectionTitle',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onQuickBookTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(70, 36),
            ),
            child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
  });

  final Venue venue;
  final VoidCallback onTap;
  final VoidCallback onBookTap;
  final VoidCallback onCallTap;
  final VoidCallback onWhatsAppTap;

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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me_rounded, size: 12, color: Colors.white),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${venue.pricingBaseAmount.toInt()}/day',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      if (venue.capacity > 0)
                        Text(
                          '👥 ${venue.capacity} Guests',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
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
                          child: const Text(
                            'Book Now',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        onPressed: onCallTap,
                        style: IconButton.outlinedFrom(
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
                        style: IconButton.filledTonalFrom(
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

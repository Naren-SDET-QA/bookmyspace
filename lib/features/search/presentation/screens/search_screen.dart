import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/maps/domain/geo_point.dart';
import '../../../../core/maps/presentation/map_view.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Recent search terms, kept in-memory for the session.
final recentSearchesProvider = StateProvider<List<String>>((ref) => const []);

/// Search screen: query + suggestions + category chips + filters + map toggle.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialCategory});

  /// Preselected category slug (set when navigating from home chips).
  final String? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _showMap = false;

  static const _popularSearches = [
    'Wedding hall',
    'Conference',
    'Birthday party',
    'Meeting room',
    'Sports ground',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _applyInitialCategory(widget.initialCategory);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory == widget.initialCategory) return;
    _applyInitialCategory(widget.initialCategory);
  }

  void _applyInitialCategory(String? category) {
    Future<void>(() {
      if (!mounted) return;
      final current = ref.read(searchQueryProvider);
      ref.read(searchQueryProvider.notifier).state = current.copyWith(
        categorySlug: () => category,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final current = ref.read(searchQueryProvider);
      ref.read(searchQueryProvider.notifier).state = current.copyWith(
        query: value.trim(),
      );
    });
  }

  void _recordSearch(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final recent = ref.read(recentSearchesProvider);
    ref.read(recentSearchesProvider.notifier).state = [
      trimmed,
      ...recent.where((t) => t != trimmed),
    ].take(6).toList();
  }

  void _submitSearch() {
    final term = _controller.text;
    _recordSearch(term);
    _onQueryChanged(term);
    FocusScope.of(context).unfocus();
  }

  void _clearFilters() {
    ref.read(searchQueryProvider.notifier).state = const VenueSearchQuery();
    _controller.clear();
  }

  Future<void> _openFilters() async {
    await showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.9,
      builder: (_) => _FilterSheet(
        initial: ref.read(searchQueryProvider),
        initialRadiusKm: ref.read(searchRadiusKmProvider),
        categories: ref.read(venueCategoriesProvider).value ?? const [],
        onApply: (updated) {
          ref.read(searchQueryProvider.notifier).state = updated;
        },
        onRadiusChanged: (km) {
          ref.read(searchRadiusKmProvider.notifier).state = km;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final radius = ref.watch(searchRadiusKmProvider);
    final area = ref.watch(searchAreaProvider);
    final recent = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  PrototypeIconButton(
                    icon: Icons.notifications_outlined,
                    showDot: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _submitSearch(),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search halls, classes, events…',
                        hintStyle: const TextStyle(
                          color: PrototypeVisuals.searchHint,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: PrototypeVisuals.searchHint,
                          size: 17,
                        ),
                        filled: true,
                        fillColor: AppTheme.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: AppTheme.brand,
                            width: 1.5,
                          ),
                        ),
                        suffixIcon: query.hasFilters
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearFilters,
                              )
                            : const Icon(
                                Icons.mic_none_rounded,
                                color: PrototypeVisuals.searchHint,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PrototypeIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: l10n.filters,
                        onPressed: _openFilters,
                      ),
                      if (query.hasFilters)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            width: 17,
                            height: 17,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppTheme.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                children: [
                  for (final chip in PrototypeVisuals.exploreChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: PrototypeFilterChip(
                          emoji: chip.emoji,
                          label: chip.label,
                          selected: chip.key == 'all'
                              ? query.categorySlug == null
                              : query.categorySlug == chip.key,
                          onTap: () {
                            ref.read(searchQueryProvider.notifier).state =
                                query.copyWith(
                              categorySlug: () =>
                                  chip.key == 'all' ? null : chip.key,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Suggestions / recent / popular when idle.
            if (query.query.isEmpty && !results.hasValue)
              _SuggestionPanel(
                recent: recent,
                popular: _popularSearches,
                onRecentTap: (term) {
                  _controller.text = term;
                  _recordSearch(term);
                  _onQueryChanged(term);
                },
                onPopularTap: (term) {
                  _controller.text = term;
                  _recordSearch(term);
                  _onQueryChanged(term);
                },
                onVoice: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎙️ Voice search is coming soon'),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: results.when(
                data: (venues) => Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${venues.length}',
                              style: const TextStyle(
                                color: AppTheme.brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' results within ${PrototypeVisuals.radiusLabel(radius)} of ${area.cityLabel.split(',').first}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (venues.isNotEmpty)
                      PrototypeIconButton(
                        icon: _showMap
                            ? Icons.view_list_rounded
                            : Icons.map_outlined,
                        tooltip: _showMap ? 'List view' : 'Map view',
                        onPressed: () => setState(() => _showMap = !_showMap),
                      ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: results.when(
                data: (venues) {
                  if (venues.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nothing matches those filters',
                      message:
                          'Try widening the radius or clearing a filter.',
                    );
                  }
                  if (_showMap) {
                    return _ResultMap(venues: venues);
                  }
                  return isWide
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisExtent: 132,
                            mainAxisSpacing: 11,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: venues.length,
                          itemBuilder: (context, i) =>
                              VenueCard(venue: venues[i], compact: true),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          itemCount: venues.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 11),
                          itemBuilder: (context, i) =>
                              VenueCard(venue: venues[i], compact: true),
                        );
                },
                loading: () => const ListSkeleton(),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(searchResultsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.recent,
    required this.popular,
    required this.onRecentTap,
    required this.onPopularTap,
    required this.onVoice,
  });

  final List<String> recent;
  final List<String> popular;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onPopularTap;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recent.isNotEmpty) ...[
            const PrototypeSectionHeader(
              title: 'Recent searches',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in recent)
                  _SuggestionChip(
                    icon: Icons.history_rounded,
                    label: term,
                    onTap: () => onRecentTap(term),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const PrototypeSectionHeader(
            title: 'Popular searches',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in popular)
                _SuggestionChip(
                  icon: Icons.trending_up_rounded,
                  label: term,
                  onTap: () => onPopularTap(term),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: PrototypeVisuals.softIconBg,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onVoice,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mic_none_rounded,
                      color: AppTheme.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Search with your voice',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    Text(
                      'Coming soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brand.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: const StadiumBorder(
        side: BorderSide(color: AppTheme.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.brand),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMap extends StatelessWidget {
  const _ResultMap({required this.venues});

  final List<Venue> venues;

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) return const SizedBox.shrink();
    final first = venues.first;
    return MapView(
      initialCenter: GeoPoint(first.latitude, first.longitude),
      initialZoom: 11,
      height: double.infinity,
      markers: [
        for (final v in venues)
          if (v.latitude != 0 && v.longitude != 0)
            MapMarkerData(point: GeoPoint(v.latitude, v.longitude), label: v.name),
      ],
    );
  }
}

/// Bottom-sheet filter panel: sort, category, price, distance, rating,
/// capacity, amenities and "available on date" (mirrors prototype `openFilters`).
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.initialRadiusKm,
    required this.categories,
    required this.onApply,
    required this.onRadiusChanged,
  });

  final VenueSearchQuery initial;
  final double initialRadiusKm;
  final List<VenueCategory> categories;
  final void Function(VenueSearchQuery) onApply;
  final ValueChanged<double> onRadiusChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late VenueSortBy _sortBy;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _categorySlug;
  String? _priceError;
  late double _radiusKm;
  double? _minRating;
  int? _minCapacity;
  Set<String> _amenities = {};
  DateTime? _availableOn;

  static const _amenityOptions = [
    'AC',
    'Parking',
    'Catering',
    'Sound System',
    'WiFi',
    'Projector',
    'Stage',
    'Generator',
  ];

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initial.sortBy;
    _categorySlug = widget.initial.categorySlug;
    _radiusKm = widget.initialRadiusKm;
    _minRating = widget.initial.minRating;
    _minCapacity = widget.initial.minCapacity;
    _amenities = widget.initial.amenities.toSet();
    _availableOn = widget.initial.availableOn;
    _minController = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableOn ?? now,
      firstDate: now,
      lastDate: DateTime(now.year, now.month + 3, now.day),
      helpText: 'Available on date',
    );
    if (picked != null) setState(() => _availableOn = picked);
  }

  void _apply() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    final priceError = AppValidators.priceRange(min: min, max: max);
    if (priceError != null) {
      setState(() => _priceError = priceError);
      return;
    }
    final updated = widget.initial.copyWith(
      sortBy: _sortBy,
      categorySlug: () => _categorySlug,
      minPrice: () => min,
      maxPrice: () => max,
      minRating: () => _minRating,
      minCapacity: () => _minCapacity,
      amenities: _amenities.toList(),
      availableOn: () => _availableOn,
    );
    widget.onRadiusChanged(_radiusKm);
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _sortBy = VenueSortBy.relevance;
      _categorySlug = null;
      _minController.clear();
      _maxController.clear();
      _radiusKm = widget.initialRadiusKm;
      _minRating = null;
      _minCapacity = null;
      _amenities = {};
      _availableOn = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppBottomSheetScrollBody(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.filters,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: _reset,
                child: Text(l10n.clearFilters),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.sortBy, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SortChip(
                label: l10n.relevance,
                selected: _sortBy == VenueSortBy.relevance,
                onTap: () => setState(() => _sortBy = VenueSortBy.relevance),
              ),
              _SortChip(
                label: l10n.priceLowToHigh,
                selected: _sortBy == VenueSortBy.priceAsc,
                onTap: () => setState(() => _sortBy = VenueSortBy.priceAsc),
              ),
              _SortChip(
                label: l10n.priceHighToLow,
                selected: _sortBy == VenueSortBy.priceDesc,
                onTap: () => setState(() => _sortBy = VenueSortBy.priceDesc),
              ),
              _SortChip(
                label: l10n.topRated,
                selected: _sortBy == VenueSortBy.rating,
                onTap: () => setState(() => _sortBy = VenueSortBy.rating),
              ),
              _SortChip(
                label: 'Nearest',
                selected: _sortBy == VenueSortBy.distance,
                onTap: () => setState(() => _sortBy = VenueSortBy.distance),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.allCategories, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrototypeFilterChip(
                emoji: '✨',
                label: l10n.allCategories,
                selected: _categorySlug == null,
                onTap: () => setState(() => _categorySlug = null),
              ),
              ...PrototypeVisuals.exploreChips
                  .where((c) => c.key != 'all')
                  .map(
                    (c) => PrototypeFilterChip(
                      emoji: c.emoji,
                      label: c.label,
                      selected: _categorySlug == c.key,
                      onTap: () => setState(() => _categorySlug = c.key),
                    ),
                  ),
              ...widget.categories
                  .where(
                    (c) => !PrototypeVisuals.exploreChips.any(
                      (p) => p.key == c.slug,
                    ),
                  )
                  .map(
                    (c) => PrototypeFilterChip(
                      emoji: PrototypeVisuals.emojiForCategorySlug(
                        c.slug,
                        icon: c.icon,
                      ),
                      label: c.name,
                      selected: _categorySlug == c.slug,
                      onTap: () => setState(() => _categorySlug = c.slug),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.pricing, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _priceError = null),
                  decoration: InputDecoration(
                    labelText: l10n.minPrice,
                    prefixText: '₹ ',
                    errorText: _priceError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _priceError = null),
                  decoration: InputDecoration(
                    labelText: l10n.maxPrice,
                    prefixText: '₹ ',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Distance', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final km in PrototypeVisuals.radiusOptionsKm)
                PrototypeFilterChip(
                  label: PrototypeVisuals.radiusLabel(km),
                  selected: _radiusKm == km,
                  onTap: () => setState(() => _radiusKm = km),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Rating', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatingChip(
                label: 'Any',
                selected: _minRating == null,
                onTap: () => setState(() => _minRating = null),
              ),
              _RatingChip(
                label: '4★+',
                selected: _minRating == 4.0,
                onTap: () => setState(() => _minRating = 4.0),
              ),
              _RatingChip(
                label: '4.5★+',
                selected: _minRating == 4.5,
                onTap: () => setState(() => _minRating = 4.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Capacity', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatingChip(
                label: 'Any',
                selected: _minCapacity == null,
                onTap: () => setState(() => _minCapacity = null),
              ),
              _RatingChip(
                label: '50+',
                selected: _minCapacity == 50,
                onTap: () => setState(() => _minCapacity = 50),
              ),
              _RatingChip(
                label: '100+',
                selected: _minCapacity == 100,
                onTap: () => setState(() => _minCapacity = 100),
              ),
              _RatingChip(
                label: '250+',
                selected: _minCapacity == 250,
                onTap: () => setState(() => _minCapacity = 250),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Amenities', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amenity in _amenityOptions)
                PrototypeFilterChip(
                  label: amenity,
                  selected: _amenities.contains(amenity),
                  onTap: () => setState(() {
                    if (!_amenities.remove(amenity)) _amenities.add(amenity);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Available on date', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Material(
            color: AppTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: _availableOn != null ? AppTheme.brand : AppTheme.line,
                width: _availableOn != null ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: AppTheme.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _availableOn == null
                            ? 'Any date'
                            : 'On ${DateFormat('EEE, d MMM').format(_availableOn!)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _availableOn == null
                              ? AppTheme.muted
                              : AppTheme.ink,
                        ),
                      ),
                    ),
                    if (_availableOn != null)
                      InkWell(
                        onTap: () => setState(() => _availableOn = null),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _apply,
                  child: Text(l10n.apply),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
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

class _SortChip extends StatelessWidget {
  const _SortChip({
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

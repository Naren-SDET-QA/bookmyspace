import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';

/// Search screen: text query + category chips + sort/filter sheet.
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

  void _clearFilters() {
    ref.read(searchQueryProvider.notifier).state = const VenueSearchQuery();
    _controller.clear();
  }

  Future<void> _openFilters() async {
    await showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.85,
      builder: (_) => _FilterSheet(
        initial: ref.read(searchQueryProvider),
        categories: ref.read(venueCategoriesProvider).value ?? const [],
        onApply: (updated) {
          ref.read(searchQueryProvider.notifier).state = updated;
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
                            : null,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: results.when(
                data: (venues) => Text.rich(
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

/// Bottom-sheet filter panel for sorting, price range and category.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.categories,
    required this.onApply,
  });

  final VenueSearchQuery initial;
  final List<VenueCategory> categories;
  final void Function(VenueSearchQuery) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late VenueSortBy _sortBy;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _categorySlug;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initial.sortBy;
    _categorySlug = widget.initial.categorySlug;
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
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _sortBy = VenueSortBy.relevance;
                    _categorySlug = null;
                    _minController.clear();
                    _maxController.clear();
                  });
                },
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
          const SizedBox(height: 8),
          Text(
            'Uses home location & radius.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _apply, child: Text(l10n.apply)),
          ),
        ],
      ),
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

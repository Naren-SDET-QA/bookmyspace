import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/validators/app_validators.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
    final categories = ref.watch(venueCategoriesProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.hasFilters
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _clearFilters,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: query.hasFilters,
                    child: const Icon(Icons.tune_rounded),
                  ),
                  tooltip: l10n.filters,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l10n.allCategories),
                    selected: query.categorySlug == null,
                    onSelected: (_) {
                      ref.read(searchQueryProvider.notifier).state = query
                          .copyWith(categorySlug: () => null);
                    },
                  ),
                ),
                ...?categories.value?.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: query.categorySlug == c.slug,
                      onSelected: (_) {
                        ref.read(searchQueryProvider.notifier).state = query
                            .copyWith(categorySlug: () => c.slug);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              data: (venues) {
                if (venues.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No results found',
                    message:
                        'Try a different keyword, category or price range.',
                  );
                }
                return isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 132,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: venues.length,
                        itemBuilder: (context, i) =>
                            VenueCard(venue: venues[i], compact: true),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: venues.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              ],
            ),
            const SizedBox(height: 20),
            Text(l10n.allCategories, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.allCategories),
                  selected: _categorySlug == null,
                  onSelected: (_) => setState(() => _categorySlug = null),
                ),
                ...widget.categories.map(
                  (c) => ChoiceChip(
                    label: Text(c.name),
                    selected: _categorySlug == c.slug,
                    onSelected: (_) => setState(() => _categorySlug = c.slug),
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
            FilledButton(onPressed: _apply, child: Text(l10n.apply)),
          ],
        ),
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../home/presentation/customer_section_providers.dart';
import '../../../location/presentation/location_providers.dart';
import '../../../location/presentation/widgets/location_bar.dart';
import '../../../location/presentation/widgets/location_picker_sheet.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../domain/ai_search_intent.dart';
import '../../../ai/presentation/voice_booking_sheet.dart';

/// Search screen: text query + section category chips + location + a
/// section-aware filter sheet. Results are always scoped to the selected
/// customer section, and a map view (`/map`) renders the same results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialCategory,
    this.initialSection,
    this.initialQuery,
    this.initialIntent,
  });

  /// Preselected category slug (set when navigating from home chips).
  final String? initialCategory;
  final String? initialSection;
  final String? initialQuery;
  final AiSearchIntent? initialIntent;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final incomingSection =
          CustomerSection.fromId(widget.initialSection) ??
          CustomerSectionCatalog.fromAny(widget.initialCategory) ??
          ref.read(selectedCustomerSectionProvider);
      if (incomingSection != null) {
        ref.read(selectedCustomerSectionProvider.notifier).state =
            incomingSection;
      }
      final category =
          widget.initialCategory ?? ref.read(selectedCustomerCategoryProvider);
      final current = ref.read(searchQueryProvider);
      final area = ref.read(searchAreaProvider);
      _controller.text = widget.initialQuery ?? '';
      final interpreted = widget.initialIntent?.toQuery(
        selectedSection: incomingSection ?? CustomerSection.functionHalls,
        area: area,
      );
      ref.read(searchQueryProvider.notifier).state =
          interpreted ??
          current.copyWith(
            query: widget.initialQuery ?? current.query,
            sectionId: () => incomingSection?.id,
            categorySlug: () =>
                category == 'all' || category == incomingSection?.id
                ? null
                : category,
            latitude: () => area.latitude,
            longitude: () => area.longitude,
            maxDistanceKm: () => area.radiusKm,
            locationNodeId: () => area.locationNodeId,
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
        sectionId: () => ref.read(selectedCustomerSectionProvider)?.id,
      );
    });
  }

  void _clearFilters() {
    final section = ref.read(selectedCustomerSectionProvider);
    final area = ref.read(searchAreaProvider);
    ref.read(searchQueryProvider.notifier).state = VenueSearchQuery(
      sectionId: section?.id,
      latitude: area.latitude,
      longitude: area.longitude,
      maxDistanceKm: area.radiusKm,
    );
    ref.read(selectedCustomerCategoryProvider.notifier).state = 'all';
    _controller.clear();
  }

  Future<void> _openLocationPicker() async {
    final area = await LocationPickerSheet.show(
      context,
      initial: ref.read(searchAreaProvider),
    );
    if (area == null || !mounted) return;
    ref.read(searchAreaProvider.notifier).state = area;
    final current = ref.read(searchQueryProvider);
    ref.read(searchQueryProvider.notifier).state = current.copyWith(
      latitude: () => area.latitude,
      longitude: () => area.longitude,
      maxDistanceKm: () => area.radiusKm,
      locationNodeId: () => area.locationNodeId,
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionFilterSheet(
        initial: ref.read(searchQueryProvider),
        categories: ref.read(venueCategoriesProvider).value ?? const [],
        section: ref.read(selectedCustomerSectionProvider),
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
    final section = ref.watch(selectedCustomerSectionProvider);
    final area = ref.watch(searchAreaProvider);
    final sectionCategories =
        section?.categories ?? const <CustomerSectionCategory>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.search),
        actions: [
          IconButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => VoiceBookingSheet(
                onConfirmed: (intent) {
                  final current = ref.read(searchQueryProvider);
                  ref.read(searchQueryProvider.notifier).state = current
                      .copyWith(
                        query: intent.location ?? intent.category ?? '',
                        minPrice: () => null,
                        maxPrice: () => intent.budget,
                        minCapacity: () => intent.guests,
                      );
                },
              ),
            ),
            tooltip: 'Voice search',
            icon: const Icon(Icons.mic_none_rounded),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.map),
            tooltip: l10n.viewOnMap,
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: LocationBar(area: area, onTap: _openLocationPicker),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (section == null)
                  ...CustomerSection.values.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${s.emoji} ${s.title}'),
                        selected: false,
                        onSelected: (_) {
                          selectCustomerSection(ref, s);
                          ref.read(searchQueryProvider.notifier).state = query
                              .copyWith(
                                sectionId: () => s.id,
                                categorySlug: () => null,
                              );
                        },
                      ),
                    );
                  })
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l10n.allCategories),
                      selected:
                          query.categorySlug == null ||
                          query.categorySlug == 'all',
                      onSelected: (_) {
                        ref
                                .read(selectedCustomerCategoryProvider.notifier)
                                .state =
                            'all';
                        ref.read(searchQueryProvider.notifier).state = query
                            .copyWith(
                              sectionId: () => section.id,
                              categorySlug: () => null,
                            );
                      },
                    ),
                  ),
                  ...sectionCategories.where((c) => c.id != 'all').map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${c.emoji} ${c.label}'),
                        selected: query.categorySlug == c.id,
                        onSelected: (_) {
                          ref
                              .read(selectedCustomerCategoryProvider.notifier)
                              .state = c
                              .id;
                          ref.read(searchQueryProvider.notifier).state = query
                              .copyWith(
                                sectionId: () => section.id,
                                categorySlug: () => c.id,
                              );
                        },
                      ),
                    );
                  }),
                ],
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
                        'Try a different keyword, category, price range or location.',
                  );
                }
                return ResponsiveLayoutBuilder(
                  builder: (context, responsive) {
                    return GridView.builder(
                      padding: EdgeInsets.all(responsive.horizontalPadding),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: responsive.resultsColumns,
                        mainAxisSpacing: responsive.gridSpacing,
                        crossAxisSpacing: responsive.gridSpacing,
                        childAspectRatio: responsive.resultsAspectRatio,
                      ),
                      itemCount: venues.length,
                      itemBuilder: (context, i) => VenueCard(venue: venues[i]),
                    );
                  },
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

/// Bottom-sheet filter panel rendered from the active section's
/// [SectionFilterSpec] list (halls, stays, PG and institutes each expose
/// their own configurable fields) plus shared sort / category / price.
class _SectionFilterSheet extends StatefulWidget {
  const _SectionFilterSheet({
    required this.initial,
    required this.categories,
    required this.onApply,
    this.section,
  });

  final VenueSearchQuery initial;
  final List<VenueCategory> categories;
  final CustomerSection? section;
  final void Function(VenueSearchQuery) onApply;

  @override
  State<_SectionFilterSheet> createState() => _SectionFilterSheetState();
}

class _SectionFilterSheetState extends State<_SectionFilterSheet> {
  late VenueSortBy _sortBy;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _categorySlug;

  // Section-specific selections.
  late DateTime? _date;
  late DateTime? _checkIn;
  late DateTime? _checkOut;
  late int? _minCapacity;
  late String? _roomType;
  late double? _minRating;
  late String? _gender;
  late String? _sharing;
  late bool? _foodIncluded;
  late double? _maxDeposit;
  late String? _classType;
  late String? _mode;
  late Set<String> _amenities;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _sortBy = q.sortBy;
    _categorySlug = q.categorySlug;
    _minController = TextEditingController(
      text: q.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxController = TextEditingController(
      text: q.maxPrice?.toStringAsFixed(0) ?? '',
    );
    _date = q.date;
    _checkIn = q.checkIn;
    _checkOut = q.checkOut;
    _minCapacity = q.minCapacity;
    _roomType = q.roomType;
    _minRating = q.minRating;
    _gender = q.gender;
    _sharing = q.sharing;
    _foodIncluded = q.foodIncluded;
    _maxDeposit = q.maxDeposit;
    _classType = q.classType;
    _mode = q.mode;
    _amenities = {...q.amenities};
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  /// Interprets a quick-chip option generically so filter specs stay
  /// configurable: `under X`, `X - Y`, `above X`, `up to X`, numbers.
  static (double?, double?) _interpretRange(String option) {
    final lower = option.toLowerCase().replaceAll(',', '');
    double? money(String s) {
      var value = double.tryParse(s);
      if (value == null) return null;
      if (s.endsWith('k') || s.endsWith('K')) value *= 1000;
      if (s.endsWith('l') || s.endsWith('L')) value *= 100000;
      return value;
    }

    if (lower.startsWith('under ')) {
      final v = money(lower.substring(6).trim());
      return (null, v);
    }
    if (lower.startsWith('up to ')) {
      final v = money(lower.substring(6).trim());
      return (null, v);
    }
    if (lower.startsWith('above ')) {
      final v = money(lower.substring(6).trim());
      return (v, null);
    }
    final parts = lower.split(RegExp(r'\s*-\s*'));
    if (parts.length == 2) {
      return (money(parts[0]), money(parts[1]));
    }
    final v = money(lower.trim());
    return (v, v);
  }

  void _apply() {
    final updated = widget.initial.copyWith(
      sortBy: _sortBy,
      sectionId: () => widget.section?.id ?? widget.initial.sectionId,
      categorySlug: () => _categorySlug,
      minPrice: () => double.tryParse(_minController.text),
      maxPrice: () => double.tryParse(_maxController.text),
      minCapacity: () => _minCapacity,
      date: () => _date,
      checkIn: () => _checkIn,
      checkOut: () => _checkOut,
      roomType: () => _roomType,
      minRating: () => _minRating,
      gender: () => _gender,
      sharing: () => _sharing,
      foodIncluded: () => _foodIncluded,
      maxDeposit: () => _maxDeposit,
      classType: () => _classType,
      mode: () => _mode,
      amenities: _amenities,
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _sortBy = VenueSortBy.relevance;
      _categorySlug = null;
      _minController.clear();
      _maxController.clear();
      _date = null;
      _checkIn = null;
      _checkOut = null;
      _minCapacity = null;
      _roomType = null;
      _minRating = null;
      _gender = null;
      _sharing = null;
      _foodIncluded = null;
      _maxDeposit = null;
      _classType = null;
      _mode = null;
      _amenities.clear();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCheckInOut() async {
    final now = DateTime.now();
    final inDate = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (inDate == null || !mounted) return;
    final outDate = await showDatePicker(
      context: context,
      initialDate:
          (_checkOut ?? inDate.add(const Duration(days: 1))).isAfter(inDate)
          ? _checkOut ?? inDate.add(const Duration(days: 1))
          : inDate.add(const Duration(days: 1)),
      firstDate: inDate.add(const Duration(days: 1)),
      lastDate: inDate.add(const Duration(days: 365)),
    );
    if (outDate == null) return;
    setState(() {
      _checkIn = inDate;
      _checkOut = outDate;
    });
  }

  String _formatDate(DateTime? d) =>
      d == null ? 'Select' : '${d.day}/${d.month}/${d.year}';

  Widget _chipRow({
    required List<String> options,
    required bool Function(String) isSelected,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: isSelected(option),
            onSelected: (_) => onTap(option),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final section = widget.section;
    final specs = section == null
        ? const <SectionFilterSpec>[]
        : CustomerSectionCatalog.filterSpecs(section);
    final amenitySpecs = section == null
        ? const <AmenityFilterSpec>[]
        : CustomerSectionCatalog.amenityFilters(section);

    // Map a spec option to its catalog amenity id (spec options are
    // configurable but use the catalog's canonical amenity ids).
    String amenityIdFor(String option) {
      final id = amenitySpecs
          .where((s) => s.id.toLowerCase() == option.toLowerCase())
          .map((s) => s.id)
          .firstOrNull;
      return id ?? option;
    }

    String amenityLabel(String option) {
      final spec = amenitySpecs
          .where((s) => s.id.toLowerCase() == option.toLowerCase())
          .firstOrNull;
      return spec == null ? option : spec.label;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      section == null
                          ? l10n.filters
                          : '${section.emoji} ${section.title} · ${l10n.filters}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: Text(l10n.clearFilters)),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Section-specific filters (configurable) ----------
              for (final spec in specs) ...[
                if (spec.field == SectionFilterField.date) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_formatDate(_date)),
                  ),
                  if (_date != null)
                    TextButton(
                      onPressed: () => setState(() => _date = null),
                      child: const Text('Clear date'),
                    ),
                ] else if (spec.field == SectionFilterField.checkInOut) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickCheckInOut,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      '${_formatDate(_checkIn)} → ${_formatDate(_checkOut)}',
                    ),
                  ),
                  if (_checkIn != null || _checkOut != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _checkIn = null;
                          _checkOut = null;
                        });
                      },
                      child: const Text('Clear dates'),
                    ),
                ] else if (spec.field == SectionFilterField.guests) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) =>
                        _minCapacity != null && _minCapacity.toString() == o,
                    onTap: (o) {
                      setState(() {
                        _minCapacity = _minCapacity?.toString() == o
                            ? null
                            : int.tryParse(o);
                      });
                    },
                  ),
                ] else if (spec.field == SectionFilterField.roomType) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _roomType == o,
                    onTap: (o) => setState(() {
                      _roomType = _roomType == o ? null : o;
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.minRating) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _minRating?.toStringAsFixed(1) == o,
                    onTap: (o) => setState(() {
                      _minRating = _minRating?.toStringAsFixed(1) == o
                          ? null
                          : double.parse(o);
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.gender) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _gender == o,
                    onTap: (o) => setState(() {
                      _gender = _gender == o ? null : o;
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.sharing) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _sharing == o,
                    onTap: (o) => setState(() {
                      _sharing = _sharing == o ? null : o;
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.food) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  FilterChip(
                    label: Text(
                      spec.options.isEmpty ? 'Included' : spec.options.first,
                    ),
                    selected: _foodIncluded == true,
                    onSelected: (selected) =>
                        setState(() => _foodIncluded = selected ? true : null),
                  ),
                ] else if (spec.field == SectionFilterField.deposit) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) =>
                        _maxDeposit != null &&
                        _maxDeposit == _interpretRange(o).$2,
                    onTap: (o) {
                      final range = _interpretRange(o);
                      setState(() {
                        _maxDeposit = _maxDeposit == range.$2 ? null : range.$2;
                      });
                    },
                  ),
                ] else if (spec.field == SectionFilterField.classType) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _classType == o,
                    onTap: (o) => setState(() {
                      _classType = _classType == o ? null : o;
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.mode) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) => _mode == o,
                    onTap: (o) => setState(() {
                      _mode = _mode == o ? null : o;
                    }),
                  ),
                ] else if (spec.field == SectionFilterField.amenities) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in spec.options)
                        ChoiceChip(
                          label: Text(amenityLabel(option)),
                          selected: _amenities.contains(amenityIdFor(option)),
                          onSelected: (_) {
                            final id = amenityIdFor(option);
                            setState(() {
                              if (_amenities.contains(id)) {
                                _amenities.remove(id);
                              } else {
                                _amenities.add(id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ] else if (spec.field == SectionFilterField.priceRange) ...[
                  Text(spec.label, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _chipRow(
                    options: spec.options,
                    isSelected: (o) {
                      final range = _interpretRange(o);
                      return _minController.text.isNotEmpty &&
                          double.tryParse(_minController.text) == range.$1 &&
                          _maxController.text.isNotEmpty &&
                          double.tryParse(_maxController.text) == range.$2;
                    },
                    onTap: (o) {
                      final range = _interpretRange(o);
                      setState(() {
                        _minController.text =
                            range.$1?.toStringAsFixed(0) ?? '';
                        _maxController.text =
                            range.$2?.toStringAsFixed(0) ?? '';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),
              ],

              // ---- Shared: sort --------------------------------------
              Text(l10n.sortBy, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _SortChip(
                    label: l10n.relevance,
                    selected: _sortBy == VenueSortBy.relevance,
                    onTap: () =>
                        setState(() => _sortBy = VenueSortBy.relevance),
                  ),
                  _SortChip(
                    label: l10n.priceLowToHigh,
                    selected: _sortBy == VenueSortBy.priceAsc,
                    onTap: () => setState(() => _sortBy = VenueSortBy.priceAsc),
                  ),
                  _SortChip(
                    label: l10n.priceHighToLow,
                    selected: _sortBy == VenueSortBy.priceDesc,
                    onTap: () =>
                        setState(() => _sortBy = VenueSortBy.priceDesc),
                  ),
                  _SortChip(
                    label: l10n.topRated,
                    selected: _sortBy == VenueSortBy.rating,
                    onTap: () => setState(() => _sortBy = VenueSortBy.rating),
                  ),
                  _SortChip(
                    label: l10n.nearest,
                    selected: _sortBy == VenueSortBy.distance,
                    onTap: () => setState(() => _sortBy = VenueSortBy.distance),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---- Shared: category ----------------------------------
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
                  if (section != null)
                    ...section.categories
                        .where((c) => c.id != 'all')
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c.label),
                            selected: _categorySlug == c.id,
                            onSelected: (_) =>
                                setState(() => _categorySlug = c.id),
                          ),
                        )
                  else
                    ...widget.categories.map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _categorySlug == c.slug,
                        onSelected: (_) =>
                            setState(() => _categorySlug = c.slug),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ---- Shared: price range -------------------------------
              Text(l10n.pricing, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.minPrice,
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/venue_import_geo_config.dart';
import '../../domain/venue_import_models.dart';
import '../../domain/venue_staging_review.dart';
import '../venue_import_providers.dart';

/// Prototype-aligned category emoji map (matches geo config + prototype).
const Map<String, String> kVenueImportCategoryEmojis = {
  'function_hall': '🏛️',
  'marriage_hall': '💍',
  'convention_center': '🏨',
  'party_hall': '🎉',
  'meeting_room': '🤝',
  'community_hall': '🏛️',
  'sports_ground': '🏆',
  'coworking_space': '💻',
  'auditorium': '🎭',
  'hotel': '🛏️',
  'resort': '🌴',
  'institute': '🎓',
  'classroom': '📚',
  'event_space': '🎪',
};

/// Admin flow: Country → State → District → Category → Fetch → Review.
class VenueImportScreen extends ConsumerWidget {
  const VenueImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wizard = ref.watch(venueImportWizardProvider);
    final categories = ref.watch(venueImportAllCategoryMappingsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Venue Import'),
        backgroundColor: AppTheme.surfaceLight,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 720 : 560),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _PrototypeHeroBanner(step: wizard.step),
              _StepIndicator(currentStep: wizard.step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  switchInCurve: AppMotion.standard,
                  switchOutCurve: AppMotion.standard,
                  child: KeyedSubtree(
                    key: ValueKey(wizard.step),
                    child: switch (wizard.step) {
                      0 => _CountryStep(
                        country: wizard.country,
                        onNext: (country) {
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .setCountry(country);
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .goToStep(1);
                        },
                      ),
                      1 => _StateStep(
                        country: wizard.country,
                        state: wizard.state,
                        onNext: (state) {
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .setState(state);
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .goToStep(2);
                        },
                        onBack: () => ref
                            .read(venueImportWizardProvider.notifier)
                            .goToStep(0),
                      ),
                      2 => _DistrictStep(
                        country: wizard.country,
                        stateName: wizard.state,
                        district: wizard.district,
                        onNext: (district) {
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .setDistrict(district);
                          ref
                              .read(venueImportWizardProvider.notifier)
                              .goToStep(3);
                        },
                        onBack: () => ref
                            .read(venueImportWizardProvider.notifier)
                            .goToStep(1),
                      ),
                      3 => categories.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => ErrorView(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(
                            venueImportAllCategoryMappingsProvider,
                          ),
                        ),
                        data: (items) => _CategoryStep(
                          categorySlug: wizard.categorySlug,
                          categories: items.isEmpty
                              ? kDefaultImportCategories
                                  .map(
                                    (c) => VenueImportCategoryMapping(
                                      id: c.slug,
                                      categorySlug: c.slug,
                                      displayName: c.displayName,
                                      osmTags: c.osmTags,
                                      googlePlaceType: c.googlePlaceType,
                                      isActive: c.isActive,
                                    ),
                                  )
                                  .toList()
                              : items,
                          isFetching: wizard.isFetching,
                          fetchError: wizard.fetchError,
                          enrichWithPlaces: wizard.enrichWithPlaces,
                          onEnrichChanged: (v) => ref
                              .read(venueImportWizardProvider.notifier)
                              .setEnrichWithPlaces(v),
                          onFetch: () => ref
                              .read(venueImportWizardProvider.notifier)
                              .prepareImportJob(),
                          onBack: () => ref
                              .read(venueImportWizardProvider.notifier)
                              .goToStep(2),
                          onCategoryChanged: (slug) => ref
                              .read(venueImportWizardProvider.notifier)
                              .setCategory(slug),
                          onToggleActive: (slug, active) async {
                            await ref
                                .read(venueImportWizardProvider.notifier)
                                .setCategoryActive(slug, active);
                            ref.invalidate(
                              venueImportAllCategoryMappingsProvider,
                            );
                            ref.invalidate(
                              venueImportCategoryMappingsProvider,
                            );
                          },
                        ),
                      ),
                      _ => VenueImportReviewScreen(
                        jobId: wizard.jobId,
                        onBack: () => ref
                            .read(venueImportWizardProvider.notifier)
                            .goToStep(3),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeHeroBanner extends StatelessWidget {
  const _PrototypeHeroBanner({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        0,
        AppTheme.pagePadding,
        8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('📥', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Engine',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  step < 4
                      ? 'Country → State → District → Category → Fetch'
                      : 'Review staged venues · owner-verified protected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
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

class VenueImportReviewScreen extends ConsumerWidget {
  const VenueImportReviewScreen({
    required this.jobId,
    required this.onBack,
    super.key,
  });

  final String jobId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (jobId.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No import job',
        message: 'Create a fetch job first to review staged venues.',
        action: OutlinedButton(onPressed: onBack, child: const Text('Back')),
      );
    }

    final staging = ref.watch(venueImportStagingProvider(jobId));

    return staging.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(venueImportStagingProvider(jobId)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.pagePadding),
            children: [
              _InfoCard(
                emoji: '⏳',
                title: 'Job ready — awaiting staged rows',
                body:
                    'Import job created. OSM discovery may still be running, '
                    'or returned no matches. Review appears when rows are staged. '
                    'Publish remains manual (admin approve).',
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
            ],
          );
        }

        final reviewable = rows
            .where((r) => r.status == VenueImportStagingStatus.pendingReview)
            .toList();
        final approved = rows
            .where((r) => r.status == VenueImportStagingStatus.approved)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            Text(
              'Review (${reviewable.length} pending · ${approved.length} approved)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              _StagingCard(
                row: row,
                onPreviewEdit: () => _openPreviewEditor(
                  context,
                  ref,
                  jobId: jobId,
                  row: row,
                ),
                onApprove: () async {
                  await ref
                      .read(venueImportWizardProvider.notifier)
                      .reviewStaging(row.id, true);
                  ref.invalidate(venueImportStagingProvider(jobId));
                },
                onReject: () async {
                  await ref
                      .read(venueImportWizardProvider.notifier)
                      .reviewStaging(row.id, false);
                  ref.invalidate(venueImportStagingProvider(jobId));
                },
                onPublish: () async {
                  try {
                    await ref
                        .read(venueImportWizardProvider.notifier)
                        .publishStaging(row.id);
                    ref.invalidate(venueImportStagingProvider(jobId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Venue published')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().contains('owner_verified') ||
                                    e.toString().contains('owner-verified')
                                ? 'Blocked: owner-verified venue protected'
                                : e.toString(),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
          ],
        );
      },
    );
  }
}

Future<void> _openPreviewEditor(
  BuildContext context,
  WidgetRef ref, {
  required String jobId,
  required VenueImportStagingRow row,
}) async {
  final nameCtrl = TextEditingController(text: row.name);
  final addressCtrl = TextEditingController(text: row.addressLine1);
  final cityCtrl = TextEditingController(text: row.city);
  final phoneCtrl = TextEditingController(text: row.phone);
  final websiteCtrl = TextEditingController(text: row.website);
  final review = const VenueStagingReviewService();

  await showAppBottomSheet<void>(
    context: context,
    maxHeightFactor: 0.85,
    backgroundColor: AppTheme.surfaceLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return AppBottomSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  kVenueImportCategoryEmojis[row.categorySlug] ?? '📌',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preview & edit',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Source ${row.source} · ${row.sourcePlaceId.isEmpty ? 'no place id' : row.sourcePlaceId}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: websiteCtrl,
              decoration: const InputDecoration(labelText: 'Website'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                try {
                  final edited = review.applyPreviewEdits(
                    row: row,
                    name: nameCtrl.text,
                    addressLine1: addressCtrl.text,
                    city: cityCtrl.text,
                    phone: phoneCtrl.text,
                    website: websiteCtrl.text,
                  );
                  await ref
                      .read(venueImportWizardProvider.notifier)
                      .updateStagingDraft(
                        stagingId: edited.id,
                        name: edited.name,
                        addressLine1: edited.addressLine1,
                        city: edited.city,
                        phone: edited.phone,
                        website: edited.website,
                        latitude: edited.latitude,
                        longitude: edited.longitude,
                      );
                  ref.invalidate(venueImportStagingProvider(jobId));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Save draft'),
            ),
          ],
        ),
      );
    },
  );

  nameCtrl.dispose();
  addressCtrl.dispose();
  cityCtrl.dispose();
  phoneCtrl.dispose();
  websiteCtrl.dispose();
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  static const _labels = ['Country', 'State', 'District', 'Category', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        4,
        AppTheme.pagePadding,
        8,
      ),
      child: Row(
        children: List.generate(_labels.length, (index) {
          final active = index <= currentStep;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active ? AppTheme.brandGradient : null,
                    color: active ? null : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? Colors.transparent : AppTheme.line,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppTheme.brand.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppTheme.ink : AppTheme.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _CountryStep extends StatelessWidget {
  const _CountryStep({required this.country, required this.onNext});

  final String country;
  final ValueChanged<String> onNext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        Text(
          'Select country',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 12),
        for (final c in kImportCountries)
          _SelectableCard(
            selected: c.code == country || country.isEmpty,
            emoji: c.emoji,
            title: c.label,
            subtitle: 'Primary market',
            onTap: () => onNext(c.code),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => onNext(country.isEmpty ? 'India' : country),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _StateStep extends StatelessWidget {
  const _StateStep({
    required this.country,
    required this.state,
    required this.onNext,
    required this.onBack,
  });

  final String country;
  final String state;
  final ValueChanged<String> onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final states =
        importCountryByCode(country)?.states.map((s) => s.name).toList() ??
            indianStateNames();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            8,
          ),
          child: Text(
            'Select state',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
            itemCount: states.length,
            itemBuilder: (_, i) {
              final s = states[i];
              return _SelectableCard(
                selected: s == state,
                emoji: '📍',
                title: s,
                onTap: () => onNext(s),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: OutlinedButton(onPressed: onBack, child: const Text('Back')),
        ),
      ],
    );
  }
}

class _DistrictStep extends StatelessWidget {
  const _DistrictStep({
    required this.country,
    required this.stateName,
    required this.district,
    required this.onNext,
    required this.onBack,
  });

  final String country;
  final String stateName;
  final String district;
  final ValueChanged<String> onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cfg = importStateConfig(country, stateName);
    final districts = (cfg?.districts.isNotEmpty == true)
        ? cfg!.districts
        : const [ImportDistrictConfig(name: kEntireState)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            8,
          ),
          child: Text(
            'Select district',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
            itemCount: districts.length,
            itemBuilder: (_, i) {
              final d = districts[i];
              return _SelectableCard(
                selected: d.name == district,
                emoji: d.name == kEntireState ? '🗺️' : '📌',
                title: d.name,
                subtitle: d.bbox != null ? 'OSM bbox ready' : 'Area / name search',
                onTap: () => onNext(d.name),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: OutlinedButton(onPressed: onBack, child: const Text('Back')),
        ),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    required this.categorySlug,
    required this.categories,
    required this.isFetching,
    required this.fetchError,
    required this.enrichWithPlaces,
    required this.onEnrichChanged,
    required this.onFetch,
    required this.onBack,
    required this.onCategoryChanged,
    required this.onToggleActive,
  });

  final String categorySlug;
  final List<VenueImportCategoryMapping> categories;
  final bool isFetching;
  final String fetchError;
  final bool enrichWithPlaces;
  final ValueChanged<bool> onEnrichChanged;
  final VoidCallback onFetch;
  final VoidCallback onBack;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function(String slug, bool active) onToggleActive;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final selectable =
        categories.where((c) => c.isActive).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            8,
          ),
          child: Text(
            'Select category',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePadding,
            ),
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 4 : 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemCount: selectable.length,
                itemBuilder: (_, i) {
                  final c = selectable[i];
                  final selected = c.categorySlug == categorySlug;
                  final emoji =
                      kVenueImportCategoryEmojis[c.categorySlug] ?? '📌';
                  return PrototypeCategoryTile(
                    emoji: emoji,
                    label: c.displayName,
                    selected: selected,
                    onTap: () => onCategoryChanged(c.categorySlug),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Enable / disable categories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final c in categories)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    c.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    c.categorySlug,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                  value: c.isActive,
                  onChanged: isFetching
                      ? null
                      : (v) => onToggleActive(c.categorySlug, v),
                ),
            ],
          ),
        ),
        if (fetchError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              8,
            ),
            child: Text(
              fetchError,
              style: const TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            AppTheme.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Optional Places enrichment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Requires GOOGLE_PLACES_API_KEY on server. OSM stays primary.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                value: enrichWithPlaces,
                onChanged: isFetching ? null : onEnrichChanged,
              ),
              FilledButton(
                onPressed: categorySlug.isEmpty || isFetching ? null : onFetch,
                child: isFetching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Fetch & stage (OSM)'),
              ),
              const SizedBox(height: 6),
              Text(
                'No auto-publish — review, approve, then publish manually.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.emoji,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(
                color: selected ? AppTheme.brand : AppTheme.line,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? AppTheme.brandGradient : null,
                    color: selected ? null : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: AppTheme.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
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
    );
  }
}

class _StagingCard extends StatelessWidget {
  const _StagingCard({
    required this.row,
    required this.onPreviewEdit,
    required this.onApprove,
    required this.onReject,
    required this.onPublish,
  });

  final VenueImportStagingRow row;
  final VoidCallback onPreviewEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final emoji =
        kVenueImportCategoryEmojis[row.categorySlug] ?? '📌';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    Text(
                      '${row.city.isNotEmpty ? row.city : row.district} · ${row.state}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                    Text(
                      '🔗 ${row.source}${row.sourcePlaceId.isEmpty ? '' : ' · ${row.sourcePlaceId}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: row.status),
            ],
          ),
          if (row.addressLine1.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.addressLine1,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (row.status != VenueImportStagingStatus.published &&
              row.status != VenueImportStagingStatus.duplicate)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onPreviewEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Preview / Edit'),
              ),
            ),
          if (row.status == VenueImportStagingStatus.pendingReview)
            Row(
              children: [
                TextButton(onPressed: onApprove, child: const Text('Approve')),
                TextButton(
                  onPressed: onReject,
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
          if (row.status == VenueImportStagingStatus.approved)
            FilledButton(onPressed: onPublish, child: const Text('Publish')),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final VenueImportStagingStatus status;

  @override
  Widget build(BuildContext context) {
    final ok = status == VenueImportStagingStatus.approved ||
        status == VenueImportStagingStatus.published;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFE6F9EE) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status.dbValue,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: ok ? AppTheme.success : AppTheme.muted,
        ),
      ),
    );
  }
}

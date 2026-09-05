import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/feature_id.dart';
import '../../../promotions/domain/promotion.dart';
import '../../../promotions/infrastructure/supabase_admin_promotion_repository.dart';
import '../../../promotions/presentation/widgets/promotion_preview.dart';
import '../../../promotions/presentation/widgets/existing_media_picker.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/domain/category_configuration.dart';

final adminPromotionsProvider = FutureProvider<List<Promotion>>((ref) {
  return SupabaseAdminPromotionRepository(
    ref.watch(supabaseProvider),
  ).listAll();
});

class AdminPromotionsScreen extends ConsumerWidget {
  const AdminPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(adminPromotionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          IconButton(
            tooltip: 'Add promotion',
            icon: const Icon(Icons.add),
            onPressed: () => _edit(context, ref, null),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Unable to load promotions.')),
        data: (promotions) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: promotions.length,
          itemBuilder: (context, index) {
            final promotion = promotions[index];
            return Card(
              child: ListTile(
                title: Text(promotion.title),
                subtitle: Text(
                  '${promotion.active ? 'Enabled' : 'Disabled'} · priority ${promotion.priority}',
                ),
                leading: CircleAvatar(child: Text('${index + 1}')),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    final repo = SupabaseAdminPromotionRepository(
                      ref.read(supabaseProvider),
                    );
                    if (action == 'edit') {
                      await _edit(context, ref, promotion);
                    } else if (action == 'preview') {
                      if (context.mounted) {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Promotion preview'),
                            content: PromotionPreview(promotion: promotion),
                          ),
                        );
                      }
                    } else if (action == 'up' || action == 'down') {
                      final next =
                          promotion.sortOrder + (action == 'up' ? -1 : 1);
                      await repo.updateOrder(id: promotion.id, sortOrder: next);
                      ref.invalidate(adminPromotionsProvider);
                    } else if (action == 'delete') {
                      await repo.delete(promotion.id);
                      ref.invalidate(adminPromotionsProvider);
                    } else if (action == 'toggle') {
                      await repo.save(_toggle(promotion));
                      ref.invalidate(adminPromotionsProvider);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'preview', child: Text('Preview')),
                    PopupMenuItem(value: 'up', child: Text('Move up')),
                    PopupMenuItem(value: 'down', child: Text('Move down')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text('Enable/Disable'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Promotion _toggle(Promotion p) => Promotion(
    id: p.id,
    title: p.title,
    shortDescription: p.shortDescription,
    description: p.description,
    bannerMediaId: p.bannerMediaId,
    active: !p.active,
    startAt: p.startAt,
    endAt: p.endAt,
    priority: p.priority,
    sortOrder: p.sortOrder,
    ctaText: p.ctaText,
    ctaAction: p.ctaAction,
    offerType: p.offerType,
    discountType: p.discountType,
    discountValue: p.discountValue,
    categoryIds: p.categoryIds,
    venueIds: p.venueIds,
    accentColor: p.accentColor,
    backgroundColor: p.backgroundColor,
    textColor: p.textColor,
    badge: p.badge,
    icon: p.icon,
  );

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Promotion? existing,
  ) async {
    final registry = ref.read(featureRegistryProvider);
    final flags = registry.configOf(FeatureId.offers).config;
    final targetCategories =
        flags['category_targeting_enabled'] as bool? ?? true;
    final targetVenues = flags['venue_targeting_enabled'] as bool? ?? true;
    final scheduling = flags['scheduling_enabled'] as bool? ?? true;
    final List<CategoryConfiguration> categories = targetCategories
        ? await ref.read(categoryConfigurationsProvider.future)
        : const <CategoryConfiguration>[];
    final List<Venue> venues = targetVenues
        ? await ref
              .read(venueRepositoryProvider)
              .search(const VenueSearchQuery())
        : const <Venue>[];
    final title = TextEditingController(text: existing?.title ?? '');
    final summary = TextEditingController(
      text: existing?.shortDescription ?? '',
    );
    final priority = TextEditingController(text: '${existing?.priority ?? 0}');
    var active = existing?.active ?? false;
    var categoryIds = {...?existing?.categoryIds};
    var venueIds = {...?existing?.venueIds};
    String? bannerMediaId = existing?.bannerMediaId;
    String? bannerUrl;
    DateTime? startAt = existing?.startAt;
    DateTime? endAt = existing?.endAt;
    final background = TextEditingController(
      text: existing?.backgroundColor ?? '',
    );
    final accent = TextEditingController(text: existing?.accentColor ?? '');
    final foreground = TextEditingController(text: existing?.textColor ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add promotion' : 'Edit promotion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: summary,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                  ),
                ),
                TextField(
                  controller: priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                SwitchListTile.adaptive(
                  title: const Text('Active'),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
                if (targetCategories)
                  ExpansionTile(
                    title: const Text('Categories (optional)'),
                    children: [
                      for (final category in categories)
                        CheckboxListTile(
                          title: Text(category.name),
                          value: categoryIds.contains(category.id),
                          onChanged: (value) => setState(() {
                            if (value == true)
                              categoryIds.add(category.id);
                            else
                              categoryIds.remove(category.id);
                          }),
                        ),
                    ],
                  ),
                if (targetVenues)
                  ExpansionTile(
                    title: const Text('Venues (optional)'),
                    children: [
                      for (final venue in venues)
                        CheckboxListTile(
                          title: Text(venue.name),
                          value: venueIds.contains(venue.id),
                          onChanged: (value) => setState(() {
                            if (value == true)
                              venueIds.add(venue.id);
                            else
                              venueIds.remove(venue.id);
                          }),
                        ),
                    ],
                  ),
                if (targetVenues)
                  ExistingMediaPicker(
                    venueIds: venueIds.toList(),
                    selectedId: bannerMediaId,
                    onSelected: (media) => setState(() {
                      bannerMediaId = media.id;
                      bannerUrl = media.url;
                    }),
                    onRemoved: () => setState(() {
                      bannerMediaId = null;
                      bannerUrl = null;
                    }),
                  ),
                PromotionPreview(
                  promotion: Promotion(
                    id: existing?.id ?? '',
                    title: title.text,
                    shortDescription: summary.text,
                    bannerMediaId: bannerMediaId,
                    active: active,
                    backgroundColor: background.text,
                    textColor: foreground.text,
                  ),
                  bannerUrl: bannerUrl,
                ),
                if (scheduling) ...[
                  ListTile(
                    title: Text(
                      startAt == null
                          ? 'Start date'
                          : 'Start: ${startAt!.toLocal().toString().split(' ').first}',
                    ),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: startAt ?? DateTime.now(),
                      );
                      if (value != null) setState(() => startAt = value);
                    },
                  ),
                  ListTile(
                    title: Text(
                      endAt == null
                          ? 'End date'
                          : 'End: ${endAt!.toLocal().toString().split(' ').first}',
                    ),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: endAt ?? startAt ?? DateTime.now(),
                      );
                      if (value != null) setState(() => endAt = value);
                    },
                  ),
                ],
                TextField(
                  controller: background,
                  decoration: const InputDecoration(
                    labelText: 'Background color (#RRGGBB)',
                  ),
                ),
                TextField(
                  controller: accent,
                  decoration: const InputDecoration(
                    labelText: 'Accent color (#RRGGBB)',
                  ),
                ),
                TextField(
                  controller: foreground,
                  decoration: const InputDecoration(
                    labelText: 'Text color (#RRGGBB)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || title.text.trim().isEmpty || !context.mounted) return;
    if (scheduling &&
        startAt != null &&
        endAt != null &&
        !endAt!.isAfter(startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }
    final p = Promotion(
      id: existing?.id ?? '',
      title: title.text.trim(),
      shortDescription: summary.text.trim(),
      description: existing?.description ?? '',
      bannerMediaId: bannerMediaId,
      active: active,
      startAt: scheduling ? startAt : null,
      endAt: scheduling ? endAt : null,
      priority: int.tryParse(priority.text) ?? 0,
      sortOrder: existing?.sortOrder ?? 0,
      ctaText: existing?.ctaText ?? '',
      ctaAction: existing?.ctaAction ?? '',
      offerType: existing?.offerType ?? 'promotional_text',
      discountType: existing?.discountType,
      discountValue: existing?.discountValue,
      categoryIds: categoryIds.toList(),
      venueIds: venueIds.toList(),
      accentColor: accent.text.trim().isEmpty ? null : accent.text.trim(),
      backgroundColor: background.text.trim().isEmpty
          ? null
          : background.text.trim(),
      textColor: foreground.text.trim().isEmpty ? null : foreground.text.trim(),
      badge: existing?.badge,
      icon: existing?.icon,
    );
    await SupabaseAdminPromotionRepository(ref.read(supabaseProvider)).save(p);
    ref.invalidate(adminPromotionsProvider);
  }
}

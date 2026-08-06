import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/content_models.dart';
import '../content_providers.dart';

/// Admin Content & Pricing Control — edit + preview for homepage, venues,
/// categories, offers/commission. Customer surfaces read the same DB config.
class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key});

  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(adminContentPreviewModeProvider);
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Content & Pricing'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: preview,
              label: Text(preview ? 'Preview ON' : 'Preview'),
              avatar: Icon(
                preview ? Icons.visibility_rounded : Icons.visibility_outlined,
                size: 18,
                color: preview ? Colors.white : AppTheme.brand,
              ),
              selectedColor: AppTheme.brand,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: preview ? Colors.white : AppTheme.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              onSelected: (v) =>
                  ref.read(adminContentPreviewModeProvider.notifier).state = v,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppTheme.brand,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.brand,
          tabs: const [
            Tab(text: 'Approvals'),
            Tab(text: 'Homepage'),
            Tab(text: 'Venues'),
            Tab(text: 'Categories'),
            Tab(text: 'Offers'),
            Tab(text: 'Preview'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ApprovalsTab(),
          _HomepageTab(),
          _VenuesTab(),
          _CategoriesTab(),
          _OffersTab(),
          _PreviewTab(),
        ],
      ),
    );
  }
}

class _ApprovalsTab extends ConsumerStatefulWidget {
  const _ApprovalsTab();

  @override
  ConsumerState<_ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends ConsumerState<_ApprovalsTab> {
  bool _busy = false;

  Future<void> _decide(AdminContentVenue v, bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(adminContentRepositoryProvider);
      await repo.approveVenue(v.id, approve: approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? '${v.name} published — now bookable'
                  : '${v.name} not approved',
            ),
          ),
        );
      }
      ref.invalidate(adminContentVenuesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(adminContentVenuesProvider);
    return venues.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminContentVenuesProvider),
      ),
      data: (items) {
        // Pending = owner-submitted, not yet published/verified.
        final pending = items
            .where((v) => !v.isActive && !v.isVerified)
            .toList();
        if (pending.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_outlined,
            title: 'No pending approvals',
            message: 'Owner-submitted halls appear here for review.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pending.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final v = pending[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            v.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PrototypeVisuals.badgeFeatBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⏳ Pending review',
                            style: TextStyle(
                              color: PrototypeVisuals.badgeFeatFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (v.city.isNotEmpty) v.city,
                        '₹${v.pricingBaseAmount.toStringAsFixed(0)}',
                        'capacity ${v.capacity}',
                        if (v.ownerVerified) '🔒 owner-verified',
                      ].join(' · '),
                      style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _decide(v, true),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Approve & publish'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : () => _decide(v, false),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomepageTab extends ConsumerWidget {
  const _HomepageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(adminHomepageSectionsProvider);
    return sections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminHomepageSectionsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.view_agenda_outlined,
            title: 'No homepage sections',
            message: 'Run the content migration to seed sections.',
          );
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          onReorderItem: (oldIndex, newIndex) async {
            final next = [...items];
            final moved = next.removeAt(oldIndex);
            next.insert(newIndex, moved);
            try {
              await ref
                  .read(adminContentRepositoryProvider)
                  .reorderHomepageSections(
                    next.map((s) => s.sectionKey).toList(),
                  );
              ref.invalidate(adminHomepageSectionsProvider);
              ref.invalidate(homepageContentConfigProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          itemBuilder: (context, index) {
            final s = items[index];
            return Card(
              key: ValueKey(s.sectionKey),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Text(
                  s.emoji.isEmpty ? '📌' : s.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  s.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${s.sectionKey} · order ${s.sortOrder}',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: s.isVisible,
                      activeThumbColor: AppTheme.brand,
                      onChanged: (v) async {
                        try {
                          await ref
                              .read(adminContentRepositoryProvider)
                              .upsertHomepageSection(
                                sectionKey: s.sectionKey,
                                title: s.title,
                                emoji: s.emoji,
                                sortOrder: s.sortOrder,
                                isVisible: v,
                                config: s.config,
                              );
                          ref.invalidate(adminHomepageSectionsProvider);
                          ref.invalidate(homepageContentConfigProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editSection(context, ref, s),
                    ),
                    const Icon(Icons.drag_handle_rounded, color: AppTheme.muted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editSection(
    BuildContext context,
    WidgetRef ref,
    HomepageSection section,
  ) async {
    final titleCtrl = TextEditingController(text: section.title);
    final emojiCtrl = TextEditingController(text: section.emoji);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${section.sectionKey}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminContentRepositoryProvider).upsertHomepageSection(
            sectionKey: section.sectionKey,
            title: titleCtrl.text.trim(),
            emoji: emojiCtrl.text.trim(),
            sortOrder: section.sortOrder,
            isVisible: section.isVisible,
            config: section.config,
          );
      ref.invalidate(adminHomepageSectionsProvider);
      ref.invalidate(homepageContentConfigProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _VenuesTab extends ConsumerWidget {
  const _VenuesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(adminContentVenuesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search venues by name or city',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                borderSide: const BorderSide(color: AppTheme.line),
              ),
            ),
            onChanged: (v) =>
                ref.read(adminContentVenueQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: venues.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(adminContentVenuesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No venues',
                  message: 'Try another search.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final v = items[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              v.name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (v.isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: PrototypeVisuals.badgeFeatBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '⭐ Featured',
                                style: TextStyle(
                                  color: PrototypeVisuals.badgeFeatFg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          if (v.city.isNotEmpty) v.city,
                          '₹${v.pricingBaseAmount.toStringAsFixed(0)}',
                          if (v.ownerVerified) '🔒 owner-verified',
                          if (!v.isActive) 'inactive',
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openVenueEditor(context, ref, v),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openVenueEditor(
    BuildContext context,
    WidgetRef ref,
    AdminContentVenue venue,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VenueContentEditor(venue: venue),
      ),
    );
    ref.invalidate(adminContentVenuesProvider);
  }
}

class _VenueContentEditor extends ConsumerStatefulWidget {
  const _VenueContentEditor({required this.venue});

  final AdminContentVenue venue;

  @override
  ConsumerState<_VenueContentEditor> createState() =>
      _VenueContentEditorState();
}

class _VenueContentEditorState extends ConsumerState<_VenueContentEditor> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _tax;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _capacity;
  late final TextEditingController _offerText;
  late final TextEditingController _offerPct;
  late final TextEditingController _amenities;
  late final TextEditingController _imageUrls;
  late bool _featured;
  late bool _active;
  bool _saving = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    _name = TextEditingController(text: v.name);
    _desc = TextEditingController(text: v.description);
    _price = TextEditingController(text: v.pricingBaseAmount.toStringAsFixed(0));
    _tax = TextEditingController(text: v.taxRate.toStringAsFixed(0));
    _phone = TextEditingController(text: v.phone);
    _website = TextEditingController(text: v.website);
    _address = TextEditingController(text: v.addressLine1);
    _city = TextEditingController(text: v.city);
    _state = TextEditingController(text: v.state);
    _lat = TextEditingController(text: v.latitude.toString());
    _lng = TextEditingController(text: v.longitude.toString());
    _capacity = TextEditingController(
      text: v.capacity > 0 ? '${v.capacity}' : '',
    );
    _offerText = TextEditingController(text: v.offerText);
    _offerPct = TextEditingController(
      text: v.offerPercent?.toStringAsFixed(0) ?? '',
    );
    _amenities = TextEditingController();
    _imageUrls = TextEditingController();
    _featured = v.isFeatured;
    _active = v.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _tax.dispose();
    _phone.dispose();
    _website.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _lat.dispose();
    _lng.dispose();
    _capacity.dispose();
    _offerText.dispose();
    _offerPct.dispose();
    _amenities.dispose();
    _imageUrls.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.venue.ownerVerified;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text(_preview ? 'Preview' : 'Edit venue'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _preview = !_preview),
            child: Text(_preview ? 'Edit' : 'Preview'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locked)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PrototypeVisuals.badgeFeatBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: const Text(
                '🔒 Owner-verified venue — protected fields cannot be overwritten. '
                'Featured / active / offers remain editable.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PrototypeVisuals.badgeFeatFg,
                  fontSize: 13,
                ),
              ),
            ),
          if (_preview) ...[
            _PreviewCard(
              name: _name.text,
              city: _city.text,
              price: double.tryParse(_price.text) ?? 0,
              featured: _featured,
              offerText: _offerText.text,
              description: _desc.text,
              phone: _phone.text,
            ),
          ] else ...[
            _field(_name, 'Name', enabled: !locked),
            _field(_desc, 'Description', maxLines: 3, enabled: !locked),
            Row(
              children: [
                Expanded(child: _field(_price, 'Base price (₹)', enabled: !locked)),
                const SizedBox(width: 10),
                Expanded(child: _field(_tax, 'Tax %')),
              ],
            ),
            _field(_phone, 'Phone', enabled: !locked),
            _field(_website, 'Website', enabled: !locked),
            _field(_address, 'Address', enabled: !locked),
            Row(
              children: [
                Expanded(child: _field(_city, 'City', enabled: !locked)),
                const SizedBox(width: 10),
                Expanded(child: _field(_state, 'State', enabled: !locked)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field(_lat, 'Latitude', enabled: !locked)),
                const SizedBox(width: 10),
                Expanded(child: _field(_lng, 'Longitude', enabled: !locked)),
              ],
            ),
            _field(_capacity, 'Capacity', enabled: !locked),
            _field(_offerText, 'Offer text'),
            _field(_offerPct, 'Offer percent'),
            _field(
              _amenities,
              'Amenities (comma-separated)',
              maxLines: 2,
            ),
            _field(
              _imageUrls,
              'Image URLs (one per line, https)',
              maxLines: 3,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Featured venue'),
              value: _featured,
              activeThumbColor: AppTheme.brand,
              onChanged: (v) => setState(() => _featured = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active / available'),
              value: _active,
              activeThumbColor: AppTheme.brand,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving || _preview ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF0EEF7),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    final tax = double.tryParse(_tax.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid base price')),
      );
      return;
    }
    if (tax == null || tax < 0 || tax > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax rate must be 0–100')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(adminContentRepositoryProvider);
    try {
      final patch = <String, dynamic>{
        'tax_rate': tax,
        'is_featured': _featured,
        'is_active': _active,
        'offer_text': _offerText.text.trim(),
        'offer_percent': _offerPct.text.trim().isEmpty
            ? null
            : double.tryParse(_offerPct.text.trim()),
      };
      if (!widget.venue.ownerVerified) {
        patch.addAll({
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'pricing_base_amount': price,
          'phone': _phone.text.trim(),
          'website': _website.text.trim(),
          'address_line1': _address.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'latitude': double.tryParse(_lat.text.trim()),
          'longitude': double.tryParse(_lng.text.trim()),
          if (_capacity.text.trim().isNotEmpty)
            'capacity': int.tryParse(_capacity.text.trim()),
        });
      }

      await repo.updateVenueContent(widget.venue.id, patch);

      final amenityText = _amenities.text.trim();
      if (amenityText.isNotEmpty) {
        final amenities = amenityText
            .split(RegExp(r'[,;\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        await repo.setVenueAmenities(widget.venue.id, amenities);
      }

      final imageText = _imageUrls.text.trim();
      if (imageText.isNotEmpty) {
        final urls = imageText
            .split(RegExp(r'\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        await repo.replaceVenueImages(
          widget.venue.id,
          [
            for (var i = 0; i < urls.length; i++)
              {
                'url': urls[i],
                'is_cover': i == 0,
                'sort_order': i,
                'alt_text': widget.venue.name,
              },
          ],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venue content saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.name,
    required this.city,
    required this.price,
    required this.featured,
    required this.offerText,
    required this.description,
    required this.phone,
  });

  final String name;
  final String city;
  final double price;
  final bool featured;
  final String offerText;
  final String description;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PrototypeVisuals.cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: PrototypeVisuals.thumbGradientFor(name),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('🏛️', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 12),
          if (featured)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PrototypeVisuals.badgeFeatBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⭐ Featured',
                style: TextStyle(
                  color: PrototypeVisuals.badgeFeatFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppTheme.ink,
            ),
          ),
          if (city.isNotEmpty)
            Text(city, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 6),
          Text(
            '₹${price.toStringAsFixed(0)} / day',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.brand,
              fontSize: 16,
            ),
          ),
          if (offerText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              offerText,
              style: const TextStyle(
                color: PrototypeVisuals.badgeFeatFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(height: 1.35)),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('📞 $phone', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = ref.watch(adminCategoryTilesProvider);
    return tiles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminCategoryTilesProvider),
      ),
      data: (items) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final t = items[i];
          return Card(
            child: ListTile(
              leading: Text(t.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(
                t.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${t.tileKey} → ${t.routeTarget}',
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              trailing: Switch.adaptive(
                value: t.isVisible,
                activeThumbColor: AppTheme.brand,
                onChanged: (v) async {
                  try {
                    await ref
                        .read(adminContentRepositoryProvider)
                        .upsertCategoryTile(
                          tileKey: t.tileKey,
                          label: t.label,
                          emoji: t.emoji,
                          routeTarget: t.routeTarget,
                          sortOrder: t.sortOrder,
                          isVisible: v,
                        );
                    ref.invalidate(adminCategoryTilesProvider);
                    ref.invalidate(homepageContentConfigProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
              onTap: () => _editTile(context, ref, t),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editTile(
    BuildContext context,
    WidgetRef ref,
    HomeCategoryTile tile,
  ) async {
    final label = TextEditingController(text: tile.label);
    final emoji = TextEditingController(text: tile.emoji);
    final route = TextEditingController(text: tile.routeTarget);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${tile.tileKey}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emoji,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: route,
              decoration: const InputDecoration(
                labelText: 'Route target',
                hintText: 'search:slug | events | courses | sports…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminContentRepositoryProvider).upsertCategoryTile(
            tileKey: tile.tileKey,
            label: label.text.trim(),
            emoji: emoji.text.trim(),
            routeTarget: route.text.trim(),
            sortOrder: tile.sortOrder,
            isVisible: tile.isVisible,
          );
      ref.invalidate(adminCategoryTilesProvider);
      ref.invalidate(homepageContentConfigProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _OffersTab extends ConsumerStatefulWidget {
  const _OffersTab();

  @override
  ConsumerState<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends ConsumerState<_OffersTab> {
  final _commission = TextEditingController(text: '10');
  final _bannerTitle = TextEditingController();
  final _bannerSubtitle = TextEditingController();
  final _offerTitle = TextEditingController();
  final _offerBody = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _commission.dispose();
    _bannerTitle.dispose();
    _bannerSubtitle.dispose();
    _offerTitle.dispose();
    _offerBody.dispose();
    super.dispose();
  }

  void _hydrate(HomepageContentConfig cfg) {
    if (_loaded) return;
    _commission.text = cfg.defaultCommissionRate.toStringAsFixed(0);
    _bannerTitle.text = '${cfg.homeBanner['title'] ?? ''}';
    _bannerSubtitle.text = '${cfg.homeBanner['subtitle'] ?? ''}';
    _offerTitle.text = '${cfg.featuredOffer['title'] ?? ''}';
    _offerBody.text = '${cfg.featuredOffer['body'] ?? ''}';
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(homepageContentConfigProvider);
    return cfg.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(homepageContentConfigProvider),
      ),
      data: (data) {
        _hydrate(data);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Commission & offers',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commission,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default commission %',
                helperText: 'Applied as platform default for new orgs',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bannerTitle,
              decoration: const InputDecoration(labelText: 'Home banner title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bannerSubtitle,
              decoration: const InputDecoration(
                labelText: 'Home banner subtitle',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _offerTitle,
              decoration: const InputDecoration(labelText: 'Featured offer title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _offerBody,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Featured offer body'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save offers & commission'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final rate = double.tryParse(_commission.text.trim());
    if (rate == null || rate < 0 || rate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission must be 0–100')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(adminContentRepositoryProvider);
    try {
      await repo.setPlatformSetting(
        key: 'default_commission_rate',
        value: {'rate': rate},
      );
      await repo.setPlatformSetting(
        key: 'home_banner',
        value: {
          'title': _bannerTitle.text.trim(),
          'subtitle': _bannerSubtitle.text.trim(),
          'is_visible': true,
          'cta_label': 'Explore',
          'cta_route': '/search',
        },
      );
      await repo.setPlatformSetting(
        key: 'featured_offer',
        value: {
          'title': _offerTitle.text.trim(),
          'body': _offerBody.text.trim(),
          'is_visible': true,
        },
      );
      ref.invalidate(homepageContentConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offers & commission saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PreviewTab extends ConsumerWidget {
  const _PreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(homepageContentConfigProvider);
    return cfg.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(homepageContentConfigProvider),
      ),
      data: (data) {
        final banner = data.homeBanner;
        final offer = data.featuredOffer;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Customer home preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (banner['is_visible'] != false)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${banner['title'] ?? 'Book spaces near you'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${banner['subtitle'] ?? ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Category tiles',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
              ),
              itemCount: data.categoryTiles.length,
              itemBuilder: (context, index) {
                final item = data.categoryTiles[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    border: Border.all(color: AppTheme.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 23)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            ...data.sections.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  s.displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (offer['is_visible'] != false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PrototypeVisuals.badgeFeatBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${offer['title'] ?? 'Featured'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PrototypeVisuals.badgeFeatFg,
                      ),
                    ),
                    Text(
                      '${offer['body'] ?? ''}',
                      style: const TextStyle(color: PrototypeVisuals.badgeFeatFg),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Default commission: ${data.defaultCommissionRate.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppTheme.muted),
            ),
          ],
        );
      },
    );
  }
}

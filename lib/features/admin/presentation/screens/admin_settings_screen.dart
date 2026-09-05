import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/admin_settings.dart';
import '../admin_settings_providers.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../promotions/presentation/widgets/existing_media_picker.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin settings'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminSettingsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Settings unavailable.')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HomeSection(settings: settings),
            _ThemeSection(settings: settings),
            _ModuleSection(settings: settings),
            const _ExistingSettingsLinks(),
          ],
        ),
      ),
    );
  }
}

class _HomeSection extends ConsumerStatefulWidget {
  const _HomeSection({required this.settings});
  final AdminSettings settings;
  @override
  ConsumerState<_HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends ConsumerState<_HomeSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.home};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Home UI',
    children: [
      for (final item in const [
        ('search_placeholder', 'Search placeholder'),
        ('hero_title', 'Hero title'),
        ('hero_subtitle', 'Hero subtitle'),
        ('primary_booking_button_text', 'Primary booking button'),
        ('banner_text', 'Banner text'),
        ('banner_media_url', 'Banner media URL'),
      ])
        TextFormField(
          initialValue: values[item.$1]?.toString() ?? '',
          decoration: InputDecoration(labelText: item.$2),
          onFieldSubmitted: (v) => setState(
            () => values[item.$1] = AdminSettings.text(
              v,
              AdminSettings.defaults.home[item.$1]!.toString(),
            ),
          ),
        ),
      FutureBuilder<List<String>>(
        future: ref
            .read(supabaseProvider)
            .from('venues')
            .select('id')
            .then(
              (rows) =>
                  (rows as List).map((row) => row['id'].toString()).toList(),
            ),
        builder: (context, snapshot) => ExistingMediaPicker(
          venueIds: snapshot.data ?? const [],
          selectedId: values['banner_media_id']?.toString(),
          onSelected: (media) => setState(() {
            values['banner_media_id'] = media.id;
            values['banner_media_url'] = media.url;
          }),
          onRemoved: () => setState(() {
            values.remove('banner_media_id');
            values.remove('banner_media_url');
          }),
        ),
      ),
      for (final item in const [
        ('home_banner_visible', 'Home banner'),
        ('search_banner_visible', 'Search banner'),
      ])
        SwitchListTile(
          title: Text(item.$2),
          value: AdminSettings.flag(values[item.$1], fallback: true),
          onChanged: (v) => setState(() => values[item.$1] = v),
        ),
      _SaveButton(section: 'home_ui', values: values),
    ],
  );
}

class _ThemeSection extends StatefulWidget {
  const _ThemeSection({required this.settings});
  final AdminSettings settings;
  @override
  State<_ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<_ThemeSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.theme};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Theme and colors',
    children: [
      for (final key in const [
        'primary_color',
        'accent_color',
        'banner_background',
        'banner_text_color',
      ])
        TextFormField(
          initialValue: values[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: key.replaceAll('_', ' ')),
          onFieldSubmitted: (v) {
            if (AdminSettings.validHex(v)) setState(() => values[key] = v);
          },
        ),
      const Text(
        'Invalid colors keep the previous value and never affect app startup.',
      ),
      _SaveButton(section: 'theme', values: values),
    ],
  );
}

class _ModuleSection extends StatefulWidget {
  const _ModuleSection({required this.settings});
  final AdminSettings settings;
  @override
  State<_ModuleSection> createState() => _ModuleSectionState();
}

class _ModuleSectionState extends State<_ModuleSection> {
  late Map<String, dynamic> values;
  @override
  void initState() {
    super.initState();
    values = {...widget.settings.modules};
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'Modules',
    children: [
      for (final key in const [
        'promotions',
        'media',
        'location',
        'availability',
        'payments',
        'check_in',
      ])
        SwitchListTile(
          title: Text(key),
          value: AdminSettings.flag(values[key]),
          onChanged: (v) => setState(() => values[key] = v),
        ),
      _SaveButton(section: 'modules', values: values),
    ],
  );
}

class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.section, required this.values});
  final String section;
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () async {
            final defaults = switch (section) {
              'home_ui' => AdminSettings.defaults.home,
              'theme' => AdminSettings.defaults.theme,
              _ => const <String, dynamic>{},
            };
            if (defaults.isEmpty) return;
            try {
              await ref
                  .read(adminSettingsRepositoryProvider)
                  .saveSection(section, defaults);
              ref.invalidate(adminSettingsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Defaults restored')),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Defaults could not be restored'),
                  ),
                );
              }
            }
          },
          child: const Text('Reset/default'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(adminSettingsRepositoryProvider)
                  .saveSection(section, values);
              ref.invalidate(adminSettingsProvider);
              if (context.mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Settings saved')));
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings could not be saved')),
                );
            }
          },
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(title),
      childrenPadding: const EdgeInsets.all(16),
      children: children,
    ),
  );
}

class _ExistingSettingsLinks extends StatelessWidget {
  const _ExistingSettingsLinks();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _LinkCard(
        'Authentication',
        'Auth providers and dependency rules',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Categories and modules',
        'Category-level capability controls',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Promotions',
        'Offers, banners, targeting and media',
        AppRoutes.adminPromotions,
      ),
      _LinkCard(
        'Booking, Location and Payments',
        'Existing authoritative configuration screens',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Media',
        'Owner media manager and storage controls',
        AppRoutes.adminFeatureConfiguration,
      ),
      _LinkCard(
        'Policies and Tax & Fees',
        'Use existing business configuration; pricing remains server-authoritative',
        AppRoutes.adminBusinessPricing,
      ),
      _LinkCard(
        'App Health',
        'Diagnostics and safe recovery status',
        AppRoutes.adminHealth,
      ),
    ],
  );
}

class _LinkCard extends StatelessWidget {
  const _LinkCard(this.title, this.subtitle, this.route);
  final String title;
  final String subtitle;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    ),
  );
}

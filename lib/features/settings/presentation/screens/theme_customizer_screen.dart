import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/settings_controller.dart';

class ThemeCustomizerScreen extends ConsumerStatefulWidget {
  const ThemeCustomizerScreen({super.key});

  @override
  ConsumerState<ThemeCustomizerScreen> createState() =>
      _ThemeCustomizerScreenState();
}

class _ThemeCustomizerScreenState extends ConsumerState<ThemeCustomizerScreen> {
  late final TextEditingController _hexController;
  var _hexError = false;

  static const _quickSwatches = [
    '#673AB7',
    '#00C9A7',
    '#2563EB',
    '#059669',
    '#E11D48',
    '#F59E0B',
    '#0284C7',
    '#DB2777',
    '#8B5CF6',
    '#166534',
    '#475569',
    '#FF6B4A',
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(themePaletteProvider);
    _hexController = TextEditingController(
      text: parseThemeHex(current) != null ? '#$current' : '',
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _applyHex(String raw) async {
    final ok = await ref.read(themePaletteProvider.notifier).setCustomHex(raw);
    if (!mounted) return;
    setState(() => _hexError = !ok);
  }

  Future<void> _reset() async {
    await ref.read(themePaletteProvider.notifier).resetToDefault();
    await ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
    if (!mounted) return;
    setState(() {
      _hexController.text = '';
      _hexError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(themePaletteProvider);
    final theme = Theme.of(context);
    final selectedPreset = ThemePalette.byName(palette);
    final customColor = parseThemeHex(palette);

    return Scaffold(
      key: const Key('theme_customizer_screen'),
      appBar: AppBar(
        title: const Text('Theme customizer'),
        actions: [
          TextButton(
            key: const Key('theme_reset_button'),
            onPressed: _reset,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        key: const Key('theme_customizer_list'),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Appearance is stored as a device preference only.'),
          const SizedBox(height: 12),
          Card(
            key: const Key('live_theme_preview_card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live preview',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The Royal Sapphire Convention Centre',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Banjara Hills, Hyderabad',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Enquire'),
                        onPressed: () {},
                      ),
                      ActionChip(
                        label: const Text('Book now'),
                        backgroundColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {mode},
            onSelectionChanged: (value) {
              ref.read(themeModeProvider.notifier).setThemeMode(value.first);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Custom primary accent',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickSwatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final hex = _quickSwatches[index];
                final color = parseThemeHex(hex)!;
                final selected =
                    customColor != null &&
                    color.toARGB32() == customColor.toARGB32();
                return InkWell(
                  key: Key('theme_swatch_${hex.substring(1)}'),
                  onTap: () {
                    _hexController.text = hex;
                    _applyHex(hex);
                  },
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: color,
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: customColor ?? theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('custom_hex_text_field'),
                  controller: _hexController,
                  maxLength: 9,
                  decoration: InputDecoration(
                    labelText: 'Custom hex (#RRGGBB)',
                    hintText: '#3F51B5',
                    errorText: _hexError
                        ? 'Enter a valid 6-character hex code (e.g. #3F51B5)'
                        : null,
                    counterText: '',
                  ),
                  onChanged: (value) {
                    final valid = parseThemeHex(value) != null;
                    setState(
                      () => _hexError = value.trim().isNotEmpty && !valid,
                    );
                    if (valid) _applyHex(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('theme_hex_apply'),
                style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                onPressed: () => _applyHex(_hexController.text),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Color palettes'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in ThemePalette.values)
                ChoiceChip(
                  key: Key('theme_preset_${item.name}'),
                  avatar: CircleAvatar(backgroundColor: item.color),
                  label: Text(item.label),
                  selected: selectedPreset == item,
                  onSelected: (_) {
                    ref.read(themePaletteProvider.notifier).setPalette(item);
                    setState(() {
                      _hexController.text = '';
                      _hexError = false;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in ThemePalette.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selectedPreset == item
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                    : theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selectedPreset == item
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: selectedPreset == item ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: item.color),
                  title: Text(item.label),
                  subtitle: Text(item.description),
                  selected: selectedPreset == item,
                  onTap: () {
                    ref.read(themePaletteProvider.notifier).setPalette(item);
                    setState(() {
                      _hexController.text = '';
                      _hexError = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

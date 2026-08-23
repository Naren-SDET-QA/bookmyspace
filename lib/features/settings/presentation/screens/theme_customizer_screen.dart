import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/settings_controller.dart';

class ThemeCustomizerScreen extends ConsumerWidget {
  const ThemeCustomizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(themePaletteProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Theme customizer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Appearance is stored as a device preference only.'),
          const SizedBox(height: 12),
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
          const Text('Color palettes'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in ThemePalette.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: item.color),
                  label: Text(item.label),
                  selected: palette == item.name,
                  onSelected: (_) =>
                      ref.read(themePaletteProvider.notifier).setPalette(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

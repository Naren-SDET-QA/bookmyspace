import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/config/test_mode.dart';
import '../../../../features/debug/presentation/screens/debug_menu_screen.dart';

/// Settings screen: theme, language and account management entry points.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final simpleMode = ref.watch(simpleModeProvider);
    final bookingMode = ref.watch(bookingModeProvider);
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: Text(l10n.themeMode),
            subtitle: Text(themeMode.name.toUpperCase()),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            leading: Icon(
              Icons.palette_outlined,
              color: themePaletteColor(palette),
            ),
            title: const Text('Color theme'),
            subtitle: Text(
              ThemePalette.values
                      .where((p) => p.name == palette)
                      .firstOrNull
                      ?.label ??
                  '#$palette',
            ),
            onTap: () => context.push(AppRoutes.themeCustomizer),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.accessibility_new_rounded),
            title: const Text('Simple Mode'),
            subtitle: const Text('Larger text and easier controls'),
            value: simpleMode,
            onChanged: (value) =>
                ref.read(simpleModeProvider.notifier).setEnabled(value),
          ),
          ListTile(
            leading: const Icon(Icons.flash_on_rounded),
            title: const Text('Booking Mode'),
            subtitle: Text(
              bookingMode == BookingMode.quick
                  ? '1-Tap Quick Booking'
                  : 'Normal booking',
            ),
            onTap: () => _showBookingModePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            subtitle: Text(AppLocalizations.languageLabel(locale)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Choose what you want to see'),
            subtitle: const Text('Customize home categories'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.categoryPreferences),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.notifications),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: Text(l10n.support),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.support),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.termsAndConditions),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.termsOfService),
          ),
          _AboutListTile(
            title: l10n.about,
            tagline: l10n.tagline,
            appName: l10n.appName,
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.deleteAccount,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmDeleteAccount(context, l10n),
          ),
        ],
      ),
    );
  }

  void _showPalettePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a color theme')),
            ...ThemePalette.values.map(
              (palette) => ListTile(
                leading: CircleAvatar(backgroundColor: palette.color),
                title: Text(palette.label),
                onTap: () {
                  ref.read(themePaletteProvider.notifier).setPalette(palette);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.colorize),
              title: const Text('Custom HEX color'),
              onTap: () {
                Navigator.pop(context);
                _showCustomHex(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomHex(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom theme color'),
        content: TextField(
          controller: controller,
          maxLength: 7,
          decoration: const InputDecoration(
            hintText: '#3F51B5',
            labelText: 'HEX color',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await ref
                  .read(themePaletteProvider.notifier)
                  .setCustomHex(controller.text);
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid 6-digit HEX color.'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('SYSTEM'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('LIGHT'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('DARK'),
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final locale in AppLocalizations.supportedLocales)
              ListTile(
                title: Text(AppLocalizations.languageLabel(locale)),
                onTap: () {
                  ref.read(localeProvider.notifier).setLocale(locale);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showBookingModePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Normal booking'),
              onTap: () {
                ref
                    .read(bookingModeProvider.notifier)
                    .setMode(BookingMode.normal);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              title: const Text('1-Tap Quick Booking'),
              onTap: () {
                ref
                    .read(bookingModeProvider.notifier)
                    .setMode(BookingMode.quick);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: const Text(
          'This action cannot be undone. Your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.go(AppRoutes.onboarding);
    }
  }
}

/// About tile that also serves as the hidden Test Mode debug-menu unlock:
/// 7 taps within a 3-second window (while [TestMode.debugMenuEnabled] is on)
/// opens [DebugMenuScreen] instead of the normal About dialog.
class _AboutListTile extends StatefulWidget {
  const _AboutListTile({
    required this.title,
    required this.tagline,
    required this.appName,
  });

  final String title;
  final String tagline;
  final String appName;

  @override
  State<_AboutListTile> createState() => _AboutListTileState();
}

class _AboutListTileState extends State<_AboutListTile> {
  int _tapCount = 0;
  DateTime? _windowStart;

  void _handleTap() {
    if (TestMode.debugMenuEnabled) {
      final now = DateTime.now();
      if (_windowStart == null ||
          now.difference(_windowStart!) > const Duration(seconds: 3)) {
        _windowStart = now;
        _tapCount = 1;
      } else {
        _tapCount++;
      }
      if (_tapCount >= 7) {
        _tapCount = 0;
        _windowStart = null;
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const DebugMenuScreen()),
        );
        return;
      }
    }
    showAboutDialog(
      context: context,
      applicationName: widget.appName,
      applicationVersion: '1.0.0',
      children: [Text(widget.tagline)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(widget.title),
      onTap: _handleTap,
    );
  }
}

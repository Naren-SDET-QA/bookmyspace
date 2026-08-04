import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/settings_controller.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

/// Settings screen: theme, language and account management entry points.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          28,
        ),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: Text(l10n.themeMode),
                  subtitle: Text(themeMode.name.toUpperCase()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showThemePicker(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: themeColor.color,
                  ),
                  title: const Text('Theme colour'),
                  subtitle: Text(themeColor.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showThemeColorPicker(context, ref, themeColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Preferences', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.language),
                  subtitle: Text(locale.languageCode.toUpperCase()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLanguagePicker(context, ref),
                ),
                const Divider(height: 1),
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
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Legal', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
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
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.about),
                  onTap: () => _showAboutDialog(context, l10n),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
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
          ),
        ],
      ),
    );
  }

  void _showThemeColorPicker(
    BuildContext context,
    WidgetRef ref,
    AppThemeColor selected,
  ) {
    showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.7,
      builder: (sheetContext) => AppBottomSheetScrollBody(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your colour',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppThemeColor.values.map((choice) {
                final active = choice == selected;
                return Semantics(
                  selected: active,
                  label: '${choice.label} theme colour',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ref
                          .read(themeColorProvider.notifier)
                          .setThemeColor(choice);
                      Navigator.pop(sheetContext);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: choice.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: choice.color.withValues(alpha: .28),
                            blurRadius: active ? 18 : 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: active
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.55,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
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
              ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showAppBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.45,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('English'),
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            title: const Text('తెలుగు'),
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('te'));
              Navigator.pop(sheetContext);
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showAboutDialog(
      context: context,
      applicationName: l10n.appName,
      applicationVersion: '1.0.0',
      children: [Text(l10n.tagline)],
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

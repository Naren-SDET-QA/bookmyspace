import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/test_mode.dart';
import '../../../../core/debug/debug_log.dart';
import '../../../../core/debug/feature_flags.dart';
import '../../../../core/debug/test_accounts.dart';
import '../../../../core/router/app_router.dart';

/// Hidden Test Mode debug menu.
///
/// Reachable by tapping the About tile 7 times in Settings while Test Mode is
/// enabled. Exposes test accounts, feature flags, network/API logs, crash and
/// performance diagnostics, a test-data reset action, and push/deep-link debug
/// tools.
class DebugMenuScreen extends ConsumerStatefulWidget {
  const DebugMenuScreen({super.key});

  @override
  ConsumerState<DebugMenuScreen> createState() => _DebugMenuScreenState();
}

class _DebugMenuScreenState extends ConsumerState<DebugMenuScreen> {
  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(featureFlagsProvider);
    final logs = ref.watch(debugLogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Mode'),
        actions: [
          IconButton(
            tooltip: 'Reset log',
            onPressed: () => DebugLog.clear(),
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Environment'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Backend'),
              subtitle: Text(TestMode.supabaseUrl),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Feature flags'),
              subtitle: const Text('Runtime toggles for this build'),
            ),
          ),
          ...flags.entries.map(
            (e) => CheckboxListTile(
              dense: true,
              title: Text(
                appFeatureFlags
                        .firstWhere(
                          (f) => f.key == e.key,
                          orElse: () => FeatureFlag(e.key, e.key),
                        )
                        .label,
              ),
              value: e.value,
              onChanged: (v) => ref
                  .read(featureFlagsProvider.notifier)
                  .setEnabled(e.key, v ?? false),
            ),
          ),
          const Divider(),
          _sectionHeader('Test accounts'),
          for (final acc in ref.watch(testAccountsProvider))
            ListTile(
              leading: Icon(
                switch (acc.role) {
                  'owner' => Icons.storefront_outlined,
                  'admin' => Icons.admin_panel_settings_outlined,
                  _ => Icons.person_outline,
                },
              ),
              title: Text(acc.label),
              subtitle: Text('${acc.email} · ${acc.role}'),
              trailing: const Icon(Icons.login_rounded),
              onTap: () {
                ref.read(selectedTestAccountProvider.notifier).state = acc;
                context.push(AppRoutes.login);
              },
            ),
          const Divider(),
          _sectionHeader('Diagnostics'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Crash logging'),
              subtitle: Text(TestMode.crashLoggingEnabled ? 'Enabled' : 'Off'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed_outlined),
              title: const Text('Performance logging'),
              subtitle: Text(
                TestMode.performanceLoggingEnabled ? 'Enabled' : 'Off',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_tethering_outlined),
              title: const Text('Push debug'),
              subtitle: const Text('Firebase Messaging token / payload log'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Push debug: no FCM token yet. Check Firebase console.',
                    ),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Deep link debug'),
              subtitle: const Text('Log incoming links and navigations'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Deep link debug: see HTTP + navigation entries below.',
                    ),
                  ),
                );
              },
            ),
          ),
          if (TestMode.testDataResetEnabled) ...[
            const Divider(),
            _sectionHeader('Test data'),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_sweep_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('Reset test data'),
                subtitle: const Text('Clear local session & logs'),
                onTap: () => _resetTestData(context),
              ),
            ),
          ],
          const Divider(),
          _sectionHeader('Network / API log'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: logs.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text('No requests logged yet.'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in entries.reversed.take(100))
                        ListTile(
                          dense: true,
                          leading: Icon(
                            switch (e.level) {
                              DebugLogLevel.error => Icons.error_outline,
                              DebugLogLevel.warning => Icons.warning_amber,
                              DebugLogLevel.verbose => Icons.notes_rounded,
                              _ => Icons.info_outline,
                            },
                            size: 18,
                            color: switch (e.level) {
                              DebugLogLevel.error => Colors.red,
                              DebugLogLevel.warning => Colors.orange,
                              _ => null,
                            },
                          ),
                          title: Text(
                            '${e.timestampLabel} [${e.source}] ${e.message}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          subtitle: e.detail == null
                              ? null
                              : Text(
                                  e.detail!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                        ),
                    ],
                  );
                },
                error: (e, _) => Text('Log error: $e'),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => context.go(AppRoutes.settings),
              child: const Text('Back to Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  Future<void> _resetTestData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset test data?'),
        content: const Text(
          'Signs out and clears the local session, logs and feature flags. '
          'Server data is not modified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      DebugLog.clear();
      ref.read(featureFlagsProvider.notifier).reset();
      ref.read(selectedTestAccountProvider.notifier).state = null;
      context.go(AppRoutes.login);
    }
  }
}

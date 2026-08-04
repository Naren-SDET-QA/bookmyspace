import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/notification.dart' as notification_domain;
import '../notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.watch(myNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          IconButton(
            tooltip: 'Notification preferences',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _NotificationPreferencesDialog(),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (unreadCount.valueOrNull != null && unreadCount.valueOrNull! > 0)
            IconButton(
              tooltip: 'Mark all as read (${unreadCount.valueOrNull!})',
              onPressed: () =>
                  ref.read(markAllNotificationsReadProvider.future),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, i) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonBox(height: 72, radius: 12),
          ),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                message: 'You will see notifications here when they arrive.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _NotificationTile(
                  notification: items[i],
                  onTap: () async {
                    await ref.read(
                      markNotificationReadProvider(items[i].id).future,
                    );
                    if (!context.mounted) return;
                    final route = items[i].targetRoute;
                    if (route != null && route.startsWith('/')) {
                      context.go(route);
                    }
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final notification_domain.Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.read ? null : AppTheme.brand.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                notification.read ? 'Read' : 'Unread',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPreferencesDialog extends ConsumerStatefulWidget {
  const _NotificationPreferencesDialog();

  @override
  ConsumerState<_NotificationPreferencesDialog> createState() =>
      _NotificationPreferencesDialogState();
}

class _NotificationPreferencesDialogState
    extends ConsumerState<_NotificationPreferencesDialog> {
  notification_domain.NotificationPreferences? _value;
  bool _saving = false;

  Future<void> _save() async {
    final value = _value;
    if (value == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(notificationRepositoryProvider).updatePreferences(value);
      ref.invalidate(notificationPreferencesProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncPreferences = ref.watch(notificationPreferencesProvider);
    return AlertDialog(
      title: const Text('Notification preferences'),
      content: asyncPreferences.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text(error.toString()),
        data: (loaded) {
          final value = _value ??= loaded;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Booking updates'),
                value: value.bookingUpdates,
                onChanged: (enabled) => setState(
                  () => _value = value.copyWith(bookingUpdates: enabled),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment updates'),
                value: value.paymentUpdates,
                onChanged: (enabled) => setState(
                  () => _value = value.copyWith(paymentUpdates: enabled),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Upcoming reminders'),
                value: value.reminders,
                onChanged: (enabled) =>
                    setState(() => _value = value.copyWith(reminders: enabled)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In-app notifications'),
                value: value.inApp,
                onChanged: (enabled) =>
                    setState(() => _value = value.copyWith(inApp: enabled)),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _value == null || _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

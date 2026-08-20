import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          if (unreadCount.valueOrNull != null && unreadCount.valueOrNull! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${unreadCount.valueOrNull!}',
                  style: TextStyle(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (unreadCount.valueOrNull != null && unreadCount.valueOrNull! > 0)
            IconButton(
              tooltip: l10n.markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 22),
              onPressed: () =>
                  ref.read(markAllNotificationsReadProvider.future),
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
            ? EmptyState(
                icon: Icons.notifications_none_rounded,
                title: l10n.noNotifications,
                message: l10n.noNotificationsMessage,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) => _NotificationTile(
                  notification: items[i],
                  onTap: () {
                    ref.read(markNotificationReadProvider(items[i].id).future);
                    _navigateToRelated(context, items[i]);
                  },
                ),
              ),
      ),
    );
  }

  void _navigateToRelated(
    BuildContext context,
    notification_domain.Notification notification,
  ) {
    final bookingId = notification.data['booking_id'] as String?;
    if (bookingId == null || bookingId.isEmpty) return;

    switch (notification.type) {
      case notification_domain.NotificationType.bookingConfirmed:
      case notification_domain.NotificationType.refundProcessed:
      case notification_domain.NotificationType.paymentReceived:
        context.push('/bookings/$bookingId/invoice');
        break;
      case notification_domain.NotificationType.bookingCancelled:
        context.push('/bookings');
        break;
      default:
        break;
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final notification_domain.Notification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.read ? null : AppTheme.brand.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                    Row(
                      children: [
                        if (!notification.read)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppLocalizations.of(context).unread,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (!notification.read &&
                            notification.createdAt != null)
                          const SizedBox(width: 8),
                        if (notification.createdAt != null)
                          Text(
                            _relativeTime(notification.createdAt!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForType(notification_domain.NotificationType type) {
    return switch (type) {
      notification_domain.NotificationType.bookingConfirmed =>
        Icons.check_circle_outline_rounded,
      notification_domain.NotificationType.bookingCancelled =>
        Icons.cancel_outlined,
      notification_domain.NotificationType.refundProcessed =>
        Icons.replay_rounded,
      notification_domain.NotificationType.paymentReceived =>
        Icons.payments_outlined,
      notification_domain.NotificationType.supportReply =>
        Icons.support_agent_rounded,
      notification_domain.NotificationType.admin =>
        Icons.admin_panel_settings_outlined,
      notification_domain.NotificationType.system => Icons.info_outline_rounded,
    };
  }

  static Color _colorForType(notification_domain.NotificationType type) {
    return switch (type) {
      notification_domain.NotificationType.bookingConfirmed => Colors.green,
      notification_domain.NotificationType.bookingCancelled => Colors.red,
      notification_domain.NotificationType.refundProcessed => Colors.teal,
      notification_domain.NotificationType.paymentReceived => Colors.blue,
      notification_domain.NotificationType.supportReply => Colors.orange,
      notification_domain.NotificationType.admin => Colors.purple,
      notification_domain.NotificationType.system => Colors.grey,
    };
  }

  static String _relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dateTime);
  }
}

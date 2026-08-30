import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/device_token_repository.dart';
import '../domain/notification.dart';
import '../domain/notification_repository.dart';
import '../infrastructure/supabase_device_token_repository.dart';
import '../infrastructure/supabase_notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseNotificationRepository(client);
});

/// Registers/deregisters this device's push notification token against the
/// signed-in user (see `OneSignalPushService.onSignedIn`/`onSignedOut`).
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseDeviceTokenRepository(client);
});

final myNotificationsProvider = FutureProvider<List<Notification>>((ref) {
  return ref.watch(notificationRepositoryProvider).myNotifications();
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final markNotificationReadProvider = FutureProvider.autoDispose
    .family<void, String>((ref, notificationId) async {
      final repo = ref.watch(notificationRepositoryProvider);
      await repo.markRead(notificationId);
      ref.invalidate(myNotificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    });

final markAllNotificationsReadProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final repo = ref.watch(notificationRepositoryProvider);
  await repo.markAllRead();
  ref.invalidate(myNotificationsProvider);
  ref.invalidate(unreadNotificationsCountProvider);
});
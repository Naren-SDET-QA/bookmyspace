import '../domain/notification.dart';

abstract interface class NotificationRepository {
  Future<List<Notification>> myNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
  Future<int> unreadCount();

  /// Records an in-app notification for the current user (RLS allows users
  /// to insert rows for themselves; used for booking lifecycle events).
  Future<void> create({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  });
}
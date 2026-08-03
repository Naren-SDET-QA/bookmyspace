import '../domain/notification.dart';

abstract interface class NotificationRepository {
  Future<List<Notification>> myNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
  Future<int> unreadCount();
}
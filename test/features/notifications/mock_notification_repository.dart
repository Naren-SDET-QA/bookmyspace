import 'package:bookmyspace/features/notifications/domain/notification.dart';
import 'package:bookmyspace/features/notifications/domain/notification_repository.dart';

/// In-memory notification repository for tests.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<Notification>? notifications})
    : _notifications = notifications ?? [];

  final List<Notification> _notifications;
  final List<Notification> _created = [];

  /// Notifications recorded via [create], in order.
  List<Notification> get created => List.unmodifiable(_created);

  @override
  Future<List<Notification>> myNotifications() async =>
      List.unmodifiable(_notifications);

  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = Notification(
        id: _notifications[index].id,
        userId: _notifications[index].userId,
        title: _notifications[index].title,
        body: _notifications[index].body,
        type: _notifications[index].type,
        data: _notifications[index].data,
        read: true,
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      _notifications[i] = Notification(
        id: n.id,
        userId: n.userId,
        title: n.title,
        body: n.body,
        type: n.type,
        data: n.data,
        read: true,
      );
    }
  }

  @override
  Future<int> unreadCount() async =>
      _notifications.where((n) => !n.read).length;

  @override
  Future<void> create({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    _created.add(
      Notification(
        id: 'created-${_created.length}',
        userId: 'u1',
        title: title,
        body: body,
        type: type,
        data: data,
        createdAt: DateTime.now(),
      ),
    );
  }
}

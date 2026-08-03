import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/notification.dart';
import '../domain/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Notification>> myNotifications() async {
    try {
      final rows = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map((r) => Notification.fromJson(r)).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'read': true, 'read_at': 'now()'})
          .eq('id', notificationId)
          .eq('user_id', _userId!);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read': true, 'read_at': 'now()'})
          .eq('user_id', _userId!);
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<int> unreadCount() async {
    try {
      final rows = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', _userId!)
          .eq('read', false);
      return rows.length;
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notifications/push_channels.dart';
import 'booking.dart';
import 'booking_reminder.dart';

abstract class LocalReminderGateway {
  Future<void> cancel(int id);
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  });
}

class NoopLocalReminderGateway implements LocalReminderGateway {
  const NoopLocalReminderGateway();

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {}
}

/// Local notifications via the already-initialized plugin.
///
/// Web has no reliable scheduled local notifications — this gateway no-ops
/// there. Exact alarms may still be denied by the OS; failures are swallowed
/// so online booking is never blocked.
class FlutterLocalReminderGateway implements LocalReminderGateway {
  FlutterLocalReminderGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool get isSupported => !kIsWeb;

  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      PushChannels.reminders,
      PushChannels.nameFor(PushChannels.reminders),
      channelDescription: PushChannels.descriptionFor(PushChannels.reminders),
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!isSupported) return;
    try {
      await _plugin.show(id, title, body, _details, payload: payload);
    } catch (_) {}
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Exact future alarms need OS timezone data and are not reliable on web.
    // Immediate (within-lead) reminders use [showNow] instead, matching the
    // legacy WorkManager "check upcoming sessions" worker.
    if (!when.isAfter(DateTime.now())) {
      await showNow(id: id, title: title, body: body, payload: payload);
    }
  }
}

class BookingReminderScheduler {
  BookingReminderScheduler({
    required LocalReminderGateway gateway,
    this.planner = const BookingReminderPlanner(),
    this.supported = true,
  }) : _gateway = gateway;

  final LocalReminderGateway _gateway;
  final BookingReminderPlanner planner;
  final bool supported;

  /// Replaces previously scheduled local reminders for [bookings].
  /// Email outbox / FCM push are not touched.
  Future<List<BookingReminder>> sync(
    List<Booking> bookings, {
    DateTime? now,
    Set<int>? previouslyScheduled,
  }) async {
    final planned = planner.plan(bookings, now ?? DateTime.now());
    if (!supported) return planned;
    final nextIds = planned.map((item) => item.notificationId).toSet();
    for (final id in previouslyScheduled ?? const <int>{}) {
      if (!nextIds.contains(id)) await _gateway.cancel(id);
    }
    for (final reminder in planned) {
      if (reminder.immediate) {
        await _gateway.showNow(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.body,
          payload: '/bookings',
        );
      } else {
        await _gateway.schedule(
          id: reminder.notificationId,
          when: reminder.fireAt,
          title: reminder.title,
          body: reminder.body,
          payload: '/bookings',
        );
      }
    }
    return planned;
  }
}

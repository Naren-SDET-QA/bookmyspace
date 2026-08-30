import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android local-notification channel definitions for push notifications,
/// mirroring the legacy BookMySpace Android app's FCMNotificationManager
/// channels (confirmations, reminders, status updates) plus a general
/// fallback channel for anything else.
abstract class PushChannels {
  static const String confirmations = 'fcm_booking_confirmations';
  static const String reminders = 'fcm_slot_reminders';
  static const String statusUpdates = 'fcm_booking_status_updates';
  static const String general = 'fcm_general';

  static const AndroidNotificationChannel _confirmationsChannel =
      AndroidNotificationChannel(
        confirmations,
        'Booking Confirmations & Passes',
        description:
            'Push notifications when venue bookings are successfully confirmed',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _remindersChannel =
      AndroidNotificationChannel(
        reminders,
        'Upcoming Slot Reminders',
        description:
            'Push notifications reminding you before your booked slot starts',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _statusChannel =
      AndroidNotificationChannel(
        statusUpdates,
        'Booking Status Updates',
        description:
            'Push notifications for check-ins, completions, and cancellations',
        importance: Importance.defaultImportance,
      );

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        general,
        'General Notifications',
        description: 'Other BookMySpace push notifications',
        importance: Importance.defaultImportance,
      );

  /// All channels that should be registered with the OS on startup.
  static const List<AndroidNotificationChannel> all = [
    _confirmationsChannel,
    _remindersChannel,
    _statusChannel,
    _generalChannel,
  ];

  /// Maps an incoming FCM `notification_type`/`type` data field (or a
  /// [dbValue]-style notification type string) to the Android channel id
  /// it should be posted on.
  static String channelIdForType(Object? type) {
    switch (type) {
      case 'booking_confirmation':
      case 'booking_confirmed':
      case 'payment_received':
        return confirmations;
      case 'slot_reminder':
        return reminders;
      case 'booking_status_update':
      case 'booking_cancelled':
      case 'refund_processed':
        return statusUpdates;
      default:
        return general;
    }
  }

  static AndroidNotificationChannel _channelById(String channelId) => all
      .firstWhere((c) => c.id == channelId, orElse: () => _generalChannel);

  static String nameFor(String channelId) => _channelById(channelId).name;

  static String descriptionFor(String channelId) =>
      _channelById(channelId).description ?? '';
}

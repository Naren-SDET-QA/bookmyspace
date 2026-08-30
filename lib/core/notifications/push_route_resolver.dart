import '../router/app_router.dart';

/// Pure mapping from an incoming FCM/push notification data payload to the
/// in-app route that should open when the user taps the notification.
///
/// Deliberately free of any Firebase/plugin dependency (unlike the push
/// notification service that calls it) so it can be unit tested directly,
/// without a platform channel or a running Firebase app.
abstract class PushRouteResolver {
  /// Resolves the data payload of a `RemoteMessage` (or an FCM `data` map
  /// more generally) to a route path. Mirrors the legacy Android app's
  /// `BookMySpaceMessagingService` routing, which always opened "My
  /// Bookings" for booking lifecycle pushes.
  static String resolve(Map<String, dynamic> data) {
    final type =
        (data['notification_type'] as String?) ??
        (data['type'] as String?) ??
        '';
    final bookingId = data['booking_id'] as String?;

    switch (type) {
      case 'booking_confirmation':
      case 'booking_confirmed':
      case 'slot_reminder':
      case 'booking_status_update':
      case 'booking_cancelled':
      case 'payment_received':
      case 'refund_processed':
        return bookingId != null && bookingId.isNotEmpty
            ? '${AppRoutes.bookings}?highlight=$bookingId'
            : AppRoutes.bookings;
      case 'support_reply':
        return AppRoutes.support;
      default:
        return AppRoutes.notifications;
    }
  }
}

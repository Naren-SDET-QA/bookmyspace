import 'package:bookmyspace/features/notifications/domain/notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses lifecycle notification and booking route', () {
    final notification = Notification.fromJson({
      'id': 'n1',
      'user_id': 'u1',
      'title': 'Payment required',
      'body': 'Pay now',
      'type': 'payment_required',
      'read': false,
      'data': {'booking_id': 'b1', 'target_route': '/bookings?bookingId=b1'},
    });

    expect(notification.type, NotificationType.paymentRequired);
    expect(notification.bookingId, 'b1');
    expect(notification.targetRoute, '/bookings?bookingId=b1');
    expect(notification.read, isFalse);
  });

  test('notification preferences default safely and serialize', () {
    final preferences = NotificationPreferences.fromJson(const {});

    expect(preferences.bookingUpdates, isTrue);
    expect(preferences.paymentUpdates, isTrue);
    expect(preferences.reminders, isTrue);
    expect(preferences.inApp, isTrue);
    expect(preferences.copyWith(reminders: false).toJson()['reminders'], false);
  });
}

import 'package:bookmyspace/core/notifications/push_route_resolver.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushRouteResolver.resolve', () {
    test('routes booking_confirmation with a booking id to bookings with highlight', () {
      final route = PushRouteResolver.resolve({
        'notification_type': 'booking_confirmation',
        'booking_id': 'b_123',
      });
      expect(route, '${AppRoutes.bookings}?highlight=b_123');
    });

    test('routes booking_confirmation without a booking id to plain bookings', () {
      final route = PushRouteResolver.resolve({
        'notification_type': 'booking_confirmation',
      });
      expect(route, AppRoutes.bookings);
    });

    test('accepts the server-side "type" field as a fallback for "notification_type"', () {
      final route = PushRouteResolver.resolve({
        'type': 'refund_processed',
        'booking_id': 'b_9',
      });
      expect(route, '${AppRoutes.bookings}?highlight=b_9');
    });

    test('routes every booking-lifecycle type to bookings', () {
      const bookingTypes = [
        'booking_confirmation',
        'booking_confirmed',
        'slot_reminder',
        'booking_status_update',
        'booking_cancelled',
        'payment_received',
        'refund_processed',
      ];
      for (final type in bookingTypes) {
        final route = PushRouteResolver.resolve({'notification_type': type});
        expect(route, AppRoutes.bookings, reason: 'type=$type');
      }
    });

    test('routes support_reply to support', () {
      final route = PushRouteResolver.resolve({'notification_type': 'support_reply'});
      expect(route, AppRoutes.support);
    });

    test('falls back to notifications for an unknown or missing type', () {
      expect(PushRouteResolver.resolve({}), AppRoutes.notifications);
      expect(
        PushRouteResolver.resolve({'notification_type': 'something_new'}),
        AppRoutes.notifications,
      );
    });

    test('go-router locations stay absolute paths with optional query', () {
      final route = PushRouteResolver.resolve({
        'type': 'booking_confirmed',
        'booking_id': 'b1',
      });
      expect(route.startsWith('/'), isTrue);
      expect(route.contains('?highlight=b1'), isTrue);
    });

    test('ignores an empty booking id (treats it like no booking id)', () {
      final route = PushRouteResolver.resolve({
        'notification_type': 'booking_confirmed',
        'booking_id': '',
      });
      expect(route, AppRoutes.bookings);
    });
  });
}

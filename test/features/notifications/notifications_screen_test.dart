import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/notifications/domain/notification.dart'
    as notif_domain;
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../booking/mock_booking_repository.dart';
import 'mock_notification_repository.dart';

Widget _app(MockNotificationRepository notificationRepo) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(notificationRepo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: AppRoutes.notifications,
        currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('shows empty state when no notifications', (tester) async {
    await tester.pumpWidget(_app(MockNotificationRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsOneWidget);
    expect(
      find.text('You will see notifications here when they arrive.'),
      findsOneWidget,
    );
  });

  testWidgets('shows notification tiles with type icons and unread badge', (
    tester,
  ) async {
    final repo = MockNotificationRepository(
      notifications: [
        notif_domain.Notification(
          id: 'n1',
          userId: 'u1',
          title: 'Booking confirmed',
          body: 'Your booking has been confirmed.',
          type: notif_domain.NotificationType.bookingConfirmed,
          data: const {'booking_id': 'b1'},
          read: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        notif_domain.Notification(
          id: 'n2',
          userId: 'u1',
          title: 'Booking cancelled',
          body: 'Your booking has been cancelled.',
          type: notif_domain.NotificationType.bookingCancelled,
          data: const {'booking_id': 'b2'},
          read: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ],
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Both notifications render.
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Booking cancelled'), findsOneWidget);

    // Only the unread one shows the badge.
    expect(find.text('Unread'), findsOneWidget);

    // Type icons render (green check for confirmed, red cancel for cancelled).
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

    // Timestamps render.
    expect(find.text('5m ago'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);
  });

  testWidgets(
    'mark all read button appears when there are unread notifications',
    (tester) async {
      final repo = MockNotificationRepository(
        notifications: [
          notif_domain.Notification(
            id: 'n1',
            userId: 'u1',
            title: 'Test',
            body: 'Body',
            type: notif_domain.NotificationType.system,
            read: false,
          ),
        ],
      );

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      // Mark all read icon is visible.
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

      // Unread count badge shows.
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets('tapping mark all read clears unread count', (tester) async {
    final repo = MockNotificationRepository(
      notifications: [
        notif_domain.Notification(
          id: 'n1',
          userId: 'u1',
          title: 'Test',
          body: 'Body',
          type: notif_domain.NotificationType.system,
          read: false,
        ),
      ],
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();

    // Mark all read button disappears after all are read.
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('tapping a confirmed booking notification navigates to invoice', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository(
      bookings: [
        MockBookingRepository.sampleBooking(
          id: 'b1',
          status: BookingStatus.confirmed,
        ),
      ],
    );
    final repo = MockNotificationRepository(
      notifications: [
        notif_domain.Notification(
          id: 'n1',
          userId: 'u1',
          title: 'Booking confirmed',
          body: 'Your booking has been confirmed.',
          type: notif_domain.NotificationType.bookingConfirmed,
          data: const {'booking_id': 'b1'},
          read: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: createAppRouter(
            initialLocation: AppRoutes.notifications,
            currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booking confirmed'));
    await tester.pumpAndSettle();

    // Navigated to invoice screen.
    expect(find.text('Invoice'), findsOneWidget);
  });

  testWidgets(
    'tapping a cancelled booking notification navigates to bookings',
    (tester) async {
      final repo = MockNotificationRepository(
        notifications: [
          notif_domain.Notification(
            id: 'n1',
            userId: 'u1',
            title: 'Booking cancelled',
            body: 'Your booking has been cancelled.',
            type: notif_domain.NotificationType.bookingCancelled,
            data: const {'booking_id': 'b2'},
            read: false,
          ),
        ],
      );

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Booking cancelled'));
      await tester.pumpAndSettle();

      // Navigated to bookings tab.
      expect(find.text('My bookings'), findsOneWidget);
    },
  );

  testWidgets('system notification does not navigate away', (tester) async {
    final repo = MockNotificationRepository(
      notifications: [
        notif_domain.Notification(
          id: 'n1',
          userId: 'u1',
          title: 'System update',
          body: 'App updated to v2.0.',
          type: notif_domain.NotificationType.system,
          read: false,
        ),
      ],
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('System update'));
    await tester.pumpAndSettle();

    // Still on notifications screen.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Notifications'),
      ),
      findsOneWidget,
    );
  });
}

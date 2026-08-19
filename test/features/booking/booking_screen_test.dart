import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/domain/notification.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/payments/presentation/payment_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../notifications/mock_notification_repository.dart';
import '../payments/mock_payment_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_booking_repository.dart';

Widget _app(
  MockBookingRepository bookingRepo, {
  MockVenueRepository? venueRepo,
  MockNotificationRepository? notificationRepo,
  String initialLocation = AppRoutes.home,
}) {
  final venue = venueRepo ?? MockVenueRepository();
  return ProviderScope(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(bookingRepo),
      venueRepositoryProvider.overrideWithValue(venue),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(
            id: 'u1',
            email: 'a@b.com',
            fullName: 'Test Customer',
            phone: '9876543210',
          ),
        ),
      ),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      notificationRepositoryProvider.overrideWithValue(
        notificationRepo ?? MockNotificationRepository(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
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

Future<void> _fillHallCustomerDetails(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsWidgets);
  await tester.enterText(fields.at(2), 'Wedding');
  await tester.pump();
}

void main() {
  testWidgets('booking flow lists slots and disables unavailable ones', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository();
    await tester.pumpWidget(_app(bookingRepo, initialLocation: '/venues/v1'));

    // Start on venue details, then enter the existing hold booking flow.
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book Now'));
    await tester.pumpAndSettle();

    expect(find.text('Morning'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
  });

  testWidgets('confirming a slot acquires a hold and creates a booking', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository();
    await tester.pumpWidget(_app(bookingRepo, initialLocation: '/venues/v1'));

    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book Now'));
    await tester.pumpAndSettle();
    await _fillHallCustomerDetails(tester);

    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm booking'), findsWidgets);

    await tester.tap(find.text('Confirm booking').last);
    await tester.pumpAndSettle();

    // Confirmation dialog.
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(bookingRepo.lastAcquiredVenueId, 'v1');
    expect(bookingRepo.lastAcquiredSlotId, 's1');
    expect(bookingRepo.lastAcquiredAmount, 35000);
    expect(bookingRepo.createdBooking, isNotNull);
  });

  testWidgets('slot conflict surfaces a message and does not create', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository()..failAcquire = true;
    await tester.pumpWidget(_app(bookingRepo, initialLocation: '/venues/v1'));

    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book Now'));
    await tester.pumpAndSettle();
    await _fillHallCustomerDetails(tester);

    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.textContaining('just taken'), findsOneWidget);
    expect(bookingRepo.createdBooking, isNull);
  });

  testWidgets('my bookings lists bookings and cancels pending ones', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository(
      bookings: [
        MockBookingRepository.sampleBooking(),
        MockBookingRepository.sampleBooking(
          id: 'b2',
          status: BookingStatus.confirmed,
        ),
      ],
    );
    final notificationRepo = MockNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          notificationRepositoryProvider.overrideWithValue(notificationRepo),
        ],
        child: const MaterialApp(
          home: MyBookingsScreen(),
          localizationsDelegates: [
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

    expect(find.text('Sunrise Function Hall'), findsNWidgets(2));

    // Only the pending booking shows a cancel button.
    expect(find.text('Cancel booking'), findsOneWidget);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.text('Keep booking'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final remaining = await bookingRepo.myBookings();
    expect(remaining.length, 1);
    expect(remaining.first.id, 'b2');

    // Cancelling a booking records a notification.
    await tester.pump();
    expect(notificationRepo.created, hasLength(1));
    expect(
      notificationRepo.created.single.type,
      NotificationType.bookingCancelled,
    );
  });

  testWidgets('confirmed bookings show a refund action that requests one', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository(
      bookings: [
        MockBookingRepository.sampleBooking(status: BookingStatus.confirmed),
      ],
    );
    final paymentRepo = MockPaymentRepository();
    final notificationRepo = MockNotificationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          paymentRepositoryProvider.overrideWithValue(paymentRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
          notificationRepositoryProvider.overrideWithValue(notificationRepo),
        ],
        child: const MaterialApp(
          home: MyBookingsScreen(),
          localizationsDelegates: [
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

    // A confirmed booking offers a refund, not a cancel.
    expect(find.text('Request refund'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);

    await tester.tap(find.text('Request refund'));
    await tester.pumpAndSettle();

    expect(find.textContaining('full refund'), findsOneWidget);
    await tester.tap(find.text('Request refund').last);
    await tester.pumpAndSettle();

    expect(paymentRepo.lastRefundBookingId, 'b1');
    expect(paymentRepo.lastRefundAmount, 41300);
    expect(find.textContaining('Refund requested'), findsOneWidget);

    // Requesting a refund records a notification.
    await tester.pump();
    expect(notificationRepo.created, hasLength(1));
    expect(
      notificationRepo.created.single.type,
      NotificationType.refundProcessed,
    );
  });

  testWidgets('confirmed bookings show digital entry pass modal with QR', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository(
      bookings: [
        MockBookingRepository.sampleBooking(
          id: 'b_conf_qr_1',
          status: BookingStatus.confirmed,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(bookingRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: MyBookingsScreen(),
          localizationsDelegates: [
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

    expect(find.text('View Entry Pass / QR'), findsOneWidget);
    await tester.tap(find.text('View Entry Pass / QR'));
    await tester.pumpAndSettle();

    expect(find.text('Digital Entry Pass'), findsOneWidget);
    expect(find.textContaining('Show this QR pass'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Digital Entry Pass'), findsNothing);
  });
}

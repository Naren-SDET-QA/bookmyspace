import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/booking/presentation/screens/my_bookings_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_booking_repository.dart';

Widget _app(
  MockBookingRepository bookingRepo, {
  MockVenueRepository? venueRepo,
}) {
  final venue = venueRepo ?? MockVenueRepository();
  return ProviderScope(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(bookingRepo),
      venueRepositoryProvider.overrideWithValue(venue),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: AppRoutes.home,
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
  testWidgets('booking flow lists slots and disables unavailable ones', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository();
    await tester.pumpWidget(_app(bookingRepo));

    // Navigate from home to a venue, then to the booking flow.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunrise Function Hall').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book now'));
    await tester.pumpAndSettle();

    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
  });

  testWidgets('confirming a slot acquires a hold and creates a booking', (
    tester,
  ) async {
    final bookingRepo = MockBookingRepository();
    await tester.pumpWidget(_app(bookingRepo));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunrise Function Hall').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book now'));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(_app(bookingRepo));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunrise Function Hall').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Book now'));
    await tester.pumpAndSettle();

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
  });
}

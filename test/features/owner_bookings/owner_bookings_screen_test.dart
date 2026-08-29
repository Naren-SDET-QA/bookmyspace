import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner_bookings/domain/owner_booking_repository.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/screens/owner_bookings_screen.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../owner_venues/mock_owner_venue_repository.dart';
import 'mock_owner_booking_repository.dart';

Widget _app(
  MockOwnerBookingRepository ownerBookingRepo,
  MockOwnerVenueRepository ownerVenueRepo, {
  String initialLocation = AppRoutes.ownerBookings,
}) {
  return ProviderScope(
    overrides: [
      ownerBookingRepositoryProvider.overrideWithValue(ownerBookingRepo),
      ownerVenueRepositoryProvider.overrideWithValue(ownerVenueRepo),
      authRepositoryProvider.overrideWithValue(
        MockAuthRepository(
          initialUser: const AuthUser(
            id: 'u1',
            email: 'owner@b.com',
            role: AppRole.venueOwner,
          ),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
        currentUser: const AuthUser(
          id: 'u1',
          email: 'owner@b.com',
          role: AppRole.venueOwner,
        ),
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

Booking _booking({
  String id = 'b1',
  BookingStatus status = BookingStatus.pending,
  bool offline = true,
  String paymentMethod = '',
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-1A2B3C',
    venueId: 'v1',
    slotId: 's1',
    bookDate: DateTime(2026, 9, 1),
    startTime: '09:00:00',
    endTime: '13:00:00',
    status: status,
    amount: 35000,
    taxAmount: 6300,
    totalAmount: 41300,
    venueName: 'Sunrise Function Hall',
    slotLabel: 'Morning',
    customerName: offline ? 'Ravi Kumar' : '',
    customerPhone: offline ? '9876543210' : '',
    isOffline: offline,
    paymentMethod: paymentMethod,
  );
}

void main() {
  testWidgets('lists bookings and shows status actions for pending bookings', (
    tester,
  ) async {
    final bookingRepo = MockOwnerBookingRepository(
      bookings: [
        _booking(),
        _booking(id: 'b2', status: BookingStatus.confirmed),
      ],
    );
    final ownerVenueRepo = MockOwnerVenueRepository()
      ..venues.add(
        const Venue(
          id: 'v1',
          name: 'Sunrise Function Hall',
          city: 'Hyderabad',
          state: 'Telangana',
          latitude: 17.38,
          longitude: 78.48,
          capacity: 500,
          pricingBaseAmount: 35000,
          category: VenueCategory(
            id: 'cat-1',
            slug: 'function_hall',
            name: 'Function Hall',
          ),
        ),
      );

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Function Hall'), findsNWidgets(2));
    expect(find.text('Ravi Kumar'), findsNWidgets(2));
    expect(find.text('BMS-1A2B3C'), findsNWidgets(2));

    // Pending booking offers Confirm action; the confirmed booking shows a status badge.
    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('Cancel booking'), findsNWidgets(2));

    // The FAB is visible when the owner has venues.
    expect(find.text('New offline booking'), findsOneWidget);
  });

  testWidgets('confirming a pending booking applies the transition', (
    tester,
  ) async {
    final bookingRepo = MockOwnerBookingRepository(bookings: [_booking()]);
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmed').first);
    await tester.pumpAndSettle();

    // Confirmation dialog: title + button both show "Confirmed".
    expect(find.text('Confirmed'), findsNWidgets(3));
    await tester.tap(find.text('Confirmed').last);
    await tester.pumpAndSettle();

    expect(bookingRepo.lastUpdatedBookingId, 'b1');
    expect(bookingRepo.lastAction, OwnerBookingAction.confirm);
    // The booking is now confirmed, so Confirm disappears and Complete appears.
    expect(find.text('Mark completed'), findsOneWidget);
  });

  testWidgets(
    'pending_owner_approval booking shows Approve/Reject and approving confirms it',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      );
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      // Confirm/Cancel actions are not offered while awaiting owner approval.
      expect(find.text('Confirmed'), findsNothing);
      expect(find.text('Cancel booking'), findsNothing);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Confirmation dialog title + button both read "Approve".
      expect(find.text('Approve'), findsNWidgets(3));
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecidedBookingId, 'b1');
      expect(bookingRepo.lastDecision, OwnerBookingDecision.approve);
      expect(find.text('Booking approved'), findsOneWidget);
      // The booking is now confirmed, so Approve/Reject disappear.
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );

  testWidgets(
    'rejecting a pending_owner_approval booking with a refund shows the refund message',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      )..decideBookingRefundStatus = 'initiated';
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('Reject'), findsNWidgets(3));
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecidedBookingId, 'b1');
      expect(bookingRepo.lastDecision, OwnerBookingDecision.reject);
      expect(find.text('Booking rejected. Refund requested.'), findsOneWidget);
    },
  );

  testWidgets(
    'rejecting an unpaid pending_owner_approval booking shows the plain rejected message',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      );
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(bookingRepo.lastDecision, OwnerBookingDecision.reject);
      expect(find.text('Booking rejected'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed decision shows the error and leaves status unchanged',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [_booking(status: BookingStatus.pendingOwnerApproval)],
      )..failDecideBooking = true;
      final ownerVenueRepo = MockOwnerVenueRepository();

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(find.text('Exception: decide failed'), findsOneWidget);
      // Buttons remain because the status never changed.
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    },
  );

  testWidgets('shows empty state when the owner has no venues', (tester) async {
    final bookingRepo = MockOwnerBookingRepository();
    final ownerVenueRepo = MockOwnerVenueRepository();

    await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
    await tester.pumpAndSettle();

    expect(find.text('No bookings for your venues yet'), findsOneWidget);
    expect(
      find.text('You need at least one venue before managing bookings.'),
      findsOneWidget,
    );
    expect(find.text('New offline booking'), findsNothing);
  });

  testWidgets(
    'shows a Pay at venue chip for a customer booking that chose it, and '
    'no chip for one that did not',
    (tester) async {
      final bookingRepo = MockOwnerBookingRepository(
        bookings: [
          _booking(
            id: 'b1',
            offline: false,
            paymentMethod: 'pay_at_venue',
            status: BookingStatus.pendingOwnerApproval,
          ),
          _booking(id: 'b2', offline: false, status: BookingStatus.confirmed),
        ],
      );
      final ownerVenueRepo = MockOwnerVenueRepository()
        ..venues.add(
          const Venue(
            id: 'v1',
            name: 'Sunrise Function Hall',
            city: 'Hyderabad',
            state: 'Telangana',
            latitude: 17.38,
            longitude: 78.48,
            capacity: 500,
            pricingBaseAmount: 35000,
            category: VenueCategory(
              id: 'cat-1',
              slug: 'function_hall',
              name: 'Function Hall',
            ),
          ),
        );

      await tester.pumpWidget(_app(bookingRepo, ownerVenueRepo));
      await tester.pumpAndSettle();

      // Only the booking that actually chose pay-at-venue shows the chip.
      expect(find.text('Pay at venue'), findsOneWidget);
    },
  );
}

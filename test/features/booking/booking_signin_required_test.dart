import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import '../notifications/mock_notification_repository.dart';
import '../venues/mock_venue_repository.dart';
import 'mock_booking_repository.dart';

/// Only email/password sign-in is enabled here so the LoginScreen renders a
/// small, deterministic set of fields (no OTP timers, no social buttons) --
/// this exercises the *real* LoginScreen, not a stand-in.
const _passwordOnlyAuthConfig = AuthConfiguration(
  authenticationEnabled: true,
  emailLoginEnabled: true,
  passwordLoginEnabled: true,
);

/// Builds the booking flow behind a router configured the same way the real
/// app configures it: an unauthenticated user is allowed to navigate to the
/// booking screen (mirrors `AppConfig.allowUnauthenticatedTestAccess` in
/// DEV), and only the final hold-acquisition step actually requires a
/// session -- reproducing exactly the situation that produced the
/// "[null] You must be signed in..." bug.
Widget _app({
  required MockAuthRepository authRepo,
  required MockBookingRepository bookingRepo,
  AuthUser? currentUser,
  bool allowUnauthenticatedTestAccess = false,
  String initialLocation = '/venues/v1',
}) {
  return ProviderScope(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(bookingRepo),
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      authRepositoryProvider.overrideWithValue(authRepo),
      authConfigurationProvider.overrideWith(
        (ref) async => _passwordOnlyAuthConfig,
      ),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
      notificationRepositoryProvider.overrideWithValue(
        MockNotificationRepository(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: createAppRouter(
        initialLocation: initialLocation,
        currentUser: currentUser,
        allowUnauthenticatedTestAccess: allowUnauthenticatedTestAccess,
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

/// Reaches the booking screen for venue `v1` (a Function Hall, which
/// requires fullName, phone and eventType -- in that render order, per
/// `CustomerSectionCatalog.requiredCustomerFields`) and fills in all three
/// fields explicitly.
///
/// This deliberately does NOT rely on `BookingScreen.initState()`
/// pre-filling fullName/phone from a signed-in user's profile: that
/// pre-fill only runs once, at mount time, so it never reflects a user
/// who signs in mid-flow (see the sign-in round-trip test below), and a
/// signed-in mock fixture that happens to omit a field (e.g. no phone)
/// would otherwise leave the form invalid -- `_confirmBooking` validates
/// the form and silently returns before ever opening the confirmation
/// dialog, which then fails a later `tap(find.text('Confirm'))` with an
/// opaque "finder found 0 widgets" error that looks unrelated to auth.
Future<void> _openBookingScreenAndFillDetails(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Book Now'));
  await tester.pumpAndSettle();

  final fields = find.byType(TextFormField);
  expect(fields, findsWidgets);
  await tester.enterText(fields.at(0), 'Jane Doe');
  await tester.enterText(fields.at(1), '9876543210');
  await tester.enterText(fields.at(2), 'Wedding');
  await tester.pump();
}

Future<void> _signInWithPassword(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), 'guest@example.com');
  await tester.enterText(fields.at(1), 'super-secret-1');
  await tester.tap(find.text('Log in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'logged-out user sees a Sign In CTA and cannot confirm a booking directly',
    (tester) async {
      final authRepo = MockAuthRepository();
      final bookingRepo = MockBookingRepository();
      await tester.pumpWidget(
        _app(
          authRepo: authRepo,
          bookingRepo: bookingRepo,
          currentUser: null,
          allowUnauthenticatedTestAccess: true,
        ),
      );
      await _openBookingScreenAndFillDetails(tester);

      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();

      // The Sign In CTA is shown instead of the normal Confirm action, and
      // there is no "[null] ..." snackbar anywhere -- the null-prefixed
      // AuthException.toString() form must never reach the user.
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Confirm booking'), findsNothing);
      expect(find.textContaining('[null]'), findsNothing);

      // There is no way to trigger a hold acquisition without authenticating
      // first: the confirm button that would call it is not in the tree.
      expect(bookingRepo.lastAcquiredVenueId, isNull);
      expect(bookingRepo.createdBooking, isNull);

      authRepo.dispose();
    },
  );

  testWidgets('tapping Sign In opens the existing login flow', (
    tester,
  ) async {
    final authRepo = MockAuthRepository();
    final bookingRepo = MockBookingRepository();
    await tester.pumpWidget(
      _app(
        authRepo: authRepo,
        bookingRepo: bookingRepo,
        currentUser: null,
        allowUnauthenticatedTestAccess: true,
      ),
    );
    await _openBookingScreenAndFillDetails(tester);
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    await tester.tap(find.text('Sign in to continue'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    authRepo.dispose();
  });

  testWidgets(
    'booking state survives the sign-in round trip and the booking can then be confirmed',
    (tester) async {
      final authRepo = MockAuthRepository();
      final bookingRepo = MockBookingRepository();
      await tester.pumpWidget(
        _app(
          authRepo: authRepo,
          bookingRepo: bookingRepo,
          currentUser: null,
          allowUnauthenticatedTestAccess: true,
        ),
      );
      await _openBookingScreenAndFillDetails(tester);

      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to continue'), findsOneWidget);

      // Navigate to auth and sign in -- this is the exact scripted
      // MockAuthRepository.signInWithPassword success path, driven through
      // the real LoginScreen widget.
      await tester.tap(find.text('Sign in to continue'));
      await tester.pumpAndSettle();
      await _signInWithPassword(tester);

      // Back on the booking screen (not the shell/home): the previously
      // selected slot, venue and entered guest details are still there --
      // proven by the normal Confirm bar reappearing (it only renders while
      // a slot remains selected) with no navigation required to get back to
      // this exact venue/date/slot state.
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Sunrise Function Hall'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsNothing);
      expect(find.text('Confirm booking'), findsWidgets);

      // The user can now continue and actually confirm the booking.
      await tester.tap(find.text('Confirm booking').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(bookingRepo.lastAcquiredVenueId, 'v1');
      expect(bookingRepo.lastAcquiredSlotId, 's1');
      expect(bookingRepo.createdBooking, isNotNull);

      authRepo.dispose();
    },
  );

  testWidgets(
    'a signed-in user sees the normal Confirm action, never the Sign In CTA',
    (tester) async {
      const user = AuthUser(
        id: 'u1',
        email: 'a@b.com',
        fullName: 'Test',
        phone: '9876543210',
      );
      final authRepo = MockAuthRepository(initialUser: user);
      final bookingRepo = MockBookingRepository();
      await tester.pumpWidget(
        _app(authRepo: authRepo, bookingRepo: bookingRepo, currentUser: user),
      );
      await _openBookingScreenAndFillDetails(tester);

      await tester.tap(find.text('Morning'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm booking'), findsWidgets);
      expect(find.text('Sign in to continue'), findsNothing);

      // Existing authorization behaviour is unchanged: confirming still
      // acquires a hold and creates the booking exactly as before.
      await tester.tap(find.text('Confirm booking').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(bookingRepo.lastAcquiredVenueId, 'v1');
      expect(bookingRepo.createdBooking, isNotNull);

      authRepo.dispose();
    },
  );
}

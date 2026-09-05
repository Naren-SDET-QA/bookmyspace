import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/booking/presentation/booking_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/notifications/presentation/notification_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';
import '../features/booking/mock_booking_repository.dart';
import '../features/courses/mock_course_repository.dart';
import '../features/events/mock_event_repository.dart';
import '../features/notifications/mock_notification_repository.dart';
import '../features/venues/mock_venue_repository.dart';

Future<String> _redirectTo(
  WidgetTester tester, {
  required String initialLocation,
  required AuthUser? currentUser,
  required bool authReady,
  bool allowUnauthenticatedTestAccess = false,
}) async {
  final router = createAppRouter(
    initialLocation: initialLocation,
    currentUser: currentUser,
    authReady: authReady,
    allowUnauthenticatedTestAccess: allowUnauthenticatedTestAccess,
  );
  await tester.pumpWidget(
    ProviderScope(
      // HomeScreen (reached after the authenticated redirect) depends on
      // these repositories; provide in-memory fakes instead of Supabase.
      overrides: [
        authRepositoryProvider.overrideWithValue(
          MockAuthRepository(
            initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
          ),
        ),
        // LoginScreen reads this directly (unrelated to auth gating, which
        // this file tests via resolveAppRedirect). Left unmocked it falls
        // through to the real Supabase-backed provider, which is never
        // initialized in tests: the provider settles to an AsyncError, but
        // LoginScreen's null-config branch renders an indeterminate
        // CircularProgressIndicator, whose perpetual animation keeps
        // scheduling frames forever -- pumpAndSettle() can never settle
        // while it's on screen. Mirrors the override login_screen_test.dart
        // already uses for the same reason.
        authConfigurationProvider.overrideWith(
          (ref) async => const AuthConfiguration(
            authenticationEnabled: true,
            emailLoginEnabled: true,
            emailOtpEnabled: true,
            phoneLoginEnabled: true,
            phoneOtpEnabled: true,
          ),
        ),
        venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
        // The shell route builds all six branch screens at once
        // (StatefulShellRoute.indexedStack), so every repository a
        // branch screen depends on needs a fake here too -- otherwise
        // an unmocked provider is left resolving against a
        // never-initialized Supabase client and pumpAndSettle times out
        // waiting for a loading state that never reaches a stable end.
        bookingRepositoryProvider.overrideWithValue(MockBookingRepository()),
        courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
        eventRepositoryProvider.overrideWithValue(MockEventRepository()),
        notificationRepositoryProvider.overrideWithValue(
          MockNotificationRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
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
  final uri = router.routeInformationProvider.value.uri.path;
  router.dispose();
  return uri;
}

void main() {
  testWidgets('unauth user on shell is redirected to login', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.shell,
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('unauth user can stay on public login route', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('authenticated user on login is redirected to shell', (
    tester,
  ) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.shell);
  });

  testWidgets('auth not ready skips gating', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: null,
      authReady: false,
    );
    expect(uri, AppRoutes.login);
  });

  testWidgets('development test access can open Home without a session', (
    tester,
  ) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.shell,
      currentUser: null,
      authReady: true,
      allowUnauthenticatedTestAccess: true,
    );
    expect(uri, AppRoutes.shell);
  });

  testWidgets('customer cannot enter owner or admin routes', (tester) async {
    final ownerUri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.ownerDashboard,
      currentUser: const AuthUser(id: 'u1'),
      authReady: true,
    );
    expect(ownerUri, AppRoutes.profile);
  });

  testWidgets('owner cannot enter admin routes', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.adminLocations,
      currentUser: const AuthUser(id: 'u1', role: AppRole.venueOwner),
      authReady: true,
    );
    expect(uri, AppRoutes.profile);
  });

  testWidgets('admin can enter admin routes', (tester) async {
    final redirect = resolveAppRedirect(
      location: AppRoutes.adminLocations,
      currentUser: const AuthUser(id: 'u1', role: AppRole.admin),
      authReady: true,
    );
    expect(redirect, isNull);
  });
}

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';
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
        venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
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

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';

Future<String> _redirectTo(
  WidgetTester tester, {
  required String initialLocation,
  required AuthUser? currentUser,
  required bool authReady,
  AppAccessRole accessRole = AppAccessRole.customer,
}) async {
  final router = createAppRouter(
    initialLocation: initialLocation,
    currentUser: currentUser,
    authReady: authReady,
    accessRole: accessRole,
  );
  final authRepository = MockAuthRepository(initialUser: currentUser);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
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
  authRepository.dispose();
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

  testWidgets('unauth user can stay on auth callback route', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: '${AppRoutes.authCallback}?error_code=otp_expired',
      currentUser: null,
      authReady: true,
    );
    expect(uri, AppRoutes.authCallback);
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

  testWidgets('customer cannot open owner management routes', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.ownerVenues,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.profile);
  });

  testWidgets('customer cannot open owner dashboard directly', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.ownerDashboard,
      currentUser: const AuthUser(id: 'customer', email: 'c@example.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.profile);
  });

  testWidgets('customer cannot open admin dashboard directly', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.adminDashboard,
      currentUser: const AuthUser(id: 'customer', email: 'c@example.com'),
      authReady: true,
    );
    expect(uri, AppRoutes.home);
  });

  testWidgets('owner can open owner management routes', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.ownerVenues,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
      accessRole: AppAccessRole.owner,
    );
    expect(uri, AppRoutes.ownerVenues);
  });

  testWidgets('owner cannot open admin routes', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.adminAudit,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
      accessRole: AppAccessRole.owner,
    );
    expect(uri, AppRoutes.home);
  });

  testWidgets('admin without owner role opens admin dashboard', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.adminDashboard,
      currentUser: const AuthUser(id: 'admin', email: 'admin@example.com'),
      authReady: true,
      accessRole: AppAccessRole.admin,
    );
    expect(uri, AppRoutes.adminDashboard);
  });

  testWidgets('admin is routed to admin dashboard after login', (tester) async {
    final uri = await _redirectTo(
      tester,
      initialLocation: AppRoutes.login,
      currentUser: const AuthUser(id: 'admin', email: 'admin@example.com'),
      authReady: true,
      accessRole: AppAccessRole.admin,
    );
    expect(uri, AppRoutes.adminDashboard);
  });
}

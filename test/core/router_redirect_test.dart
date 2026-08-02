import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _redirectTo(
  WidgetTester tester, {
  required String initialLocation,
  required AuthUser? currentUser,
  required bool authReady,
}) async {
  final router = createAppRouter(
    initialLocation: initialLocation,
    currentUser: currentUser,
    authReady: authReady,
  );
  await tester.pumpWidget(
    ProviderScope(
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
}

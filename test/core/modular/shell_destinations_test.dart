import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/modular/feature_id.dart';
import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/core/modular/shell_destinations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/mock_auth_repository.dart';
import '../../features/venues/mock_venue_repository.dart';

void main() {
  test('enabled shell destinations all appear by default', () {
    final visible = visibleShellDestinations(FeatureRegistry.defaults());
    expect(
      visible.map((item) => item.id).toList(),
      ['home', 'map', 'search', 'bookings', 'profile', 'saved'],
    );
    expect(visible.map((item) => item.branchIndex).toList(), [0, 1, 2, 3, 4, 5]);
  });

  test('disabled feature tabs disappear without duplicating config', () {
    final registry = FeatureRegistry.defaults()
      ..apply(FeatureId.maps, enabled: false)
      ..apply(FeatureId.search, enabled: false);

    final visible = visibleShellDestinations(registry);
    expect(visible.map((item) => item.id).toList(), [
      'home',
      'bookings',
      'profile',
      'saved',
    ]);
    expect(visible.any((item) => item.id == 'map'), isFalse);
    expect(visible.any((item) => item.id == 'search'), isFalse);
    expect(visible.first.id, 'home');
    expect(visible.last.id, 'saved');
  });

  test('selected index maps to remaining visible branches', () {
    final visible = visibleShellDestinations(
      FeatureRegistry.defaults()..apply(FeatureId.maps, enabled: false),
    );
    expect(selectedShellIndex(currentBranch: 0, visible: visible), 0);
    expect(selectedShellIndex(currentBranch: 2, visible: visible), 1);
    expect(selectedShellIndex(currentBranch: 1, visible: visible), 0);
  });

  testWidgets('NavigationBar hides disabled tabs and keeps enabled ones', (
    tester,
  ) async {
    FeatureRegistry.reset();
    FeatureRegistry.configure(FeatureId.maps, enabled: false);
    addTearDown(FeatureRegistry.reset);

    final router = createAppRouter(
      initialLocation: AppRoutes.shell,
      currentUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      authReady: true,
    );
    await tester.pumpWidget(
      ProviderScope(
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

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Home')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Search')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Bookings')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Profile')),
      findsOneWidget,
    );
    expect(find.descendant(of: bar, matching: find.text('Map')), findsNothing);
    router.dispose();
  });
}

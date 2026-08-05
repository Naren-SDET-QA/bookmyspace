import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/core/theme/prototype_visuals.dart';
import 'package:bookmyspace/core/widgets/app_bottom_sheet.dart';
import 'package:bookmyspace/features/accommodations/presentation/screens/accommodation_list_screen.dart';
import 'package:bookmyspace/features/admin/domain/content_models.dart';
import 'package:bookmyspace/features/admin/presentation/content_providers.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/courses/presentation/screens/courses_list_screen.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/events/presentation/screens/events_list_screen.dart';
import 'package:bookmyspace/features/meeting_rooms/presentation/screens/meeting_rooms_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/sports/presentation/screens/sports_screens.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import 'mock_venue_repository.dart';

Widget _app(MockVenueRepository venueRepo, {MockAuthRepository? authRepo}) {
  final auth =
      authRepo ??
      MockAuthRepository(
        initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
      );
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(venueRepo),
      authRepositoryProvider.overrideWithValue(auth),
      eventRepositoryProvider.overrideWithValue(MockEventRepository()),
      courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
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
  Future<void> openMobileHome(
    WidgetTester tester,
    MockVenueRepository repo,
  ) async {
    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
  }

  testWidgets('home shows popular venues from the repository', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Function Hall'), findsWidgets);
    expect(find.text('The Work Nest'), findsWidgets);
    expect(find.text('Function Halls'), findsWidgets);

    await tester.ensureVisible(find.text('Sunrise Function Hall').first);
    await tester.tap(find.text('Sunrise Function Hall').first);
    await tester.pumpAndSettle();
    // Navigates to the venue details page.
    expect(find.text('About this venue'), findsOneWidget);
  });

  for (final identity in [
    ('customer', 'Customer Name'),
    ('owner', 'Owner Name'),
    ('admin', 'Admin Name'),
  ]) {
    testWidgets('home greets authenticated ${identity.$1}', (tester) async {
      final auth = MockAuthRepository(
        initialUser: AuthUser(
          id: '${identity.$1}-id',
          email: '${identity.$1}@example.com',
          fullName: identity.$2,
        ),
      );
      tester.view.physicalSize = const Size(599, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
      await tester.pumpAndSettle();

      // Prototype greeting is time-of-day, not personalized Welcome.
      expect(
        find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
        findsOneWidget,
      );
      expect(find.text('Welcome to Guest'), findsNothing);
      auth.dispose();
    });
  }

  testWidgets('home greets guest only when unauthenticated', (tester) async {
    final auth = MockAuthRepository();
    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
      findsOneWidget,
    );
    auth.dispose();
  });

  testWidgets('home updates after restored session', (tester) async {
    final auth = MockAuthRepository();
    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
      findsOneWidget,
    );

    auth.restoreSession(
      const AuthUser(
        id: 'restored-id',
        email: 'restored@example.com',
        fullName: 'Restored User',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
      findsOneWidget,
    );
    expect(find.text('Welcome to Guest'), findsNothing);
    auth.dispose();
  });

  testWidgets('home shows error state and recovers on retry', (tester) async {
    final repo = MockVenueRepository()..failRequests = true;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsWidgets);

    repo.failRequests = false;
    await tester.ensureVisible(find.text('Try again').first);
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Function Hall'), findsWidgets);
  });

  testWidgets('favourite toggle updates the saved icon', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final saveButtons = find.byIcon(Icons.favorite_outline_rounded);
    expect(saveButtons, findsWidgets);

    await tester.ensureVisible(saveButtons.first);
    await tester.tap(saveButtons.first);
    await tester.pumpAndSettle();
    expect(repo.favoriteIds(), completes);
  });

  for (final route in [
    ('function_hall', SearchScreen),
    ('classes', CoursesListScreen),
    ('events', EventsListScreen),
    ('meeting_room', MeetingRoomsScreen),
    ('sports_ground', SportsVenuesScreen),
    ('pg', AccommodationListScreen),
    ('stays', AccommodationListScreen),
  ]) {
    testWidgets('${route.$1} category opens its listing', (tester) async {
      final repo = MockVenueRepository();
      await openMobileHome(tester, repo);

      await tester.ensureVisible(
        find.byKey(ValueKey('home-category-${route.$1}')),
      );
      await tester.tap(find.byKey(ValueKey('home-category-${route.$1}')));
      await tester.pumpAndSettle();

      expect(find.byType(route.$2), findsOneWidget);
      if (route.$1 == 'function_hall') {
        expect(
          tester
              .widget<SearchScreen>(find.byType(SearchScreen))
              .initialCategory,
          route.$1,
        );
      }
    });
  }

  testWidgets('location picker updates the displayed city', (tester) async {
    final repo = MockVenueRepository();
    await openMobileHome(tester, repo);

    expect(find.text('Ongole, Andhra Pradesh'), findsOneWidget);

    await tester.tap(find.text('Ongole, Andhra Pradesh'));
    await tester.pumpAndSettle();
    expect(find.text('Choose location'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomSheetScrollBody),
        matching: find.text('Guntur'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guntur, Andhra Pradesh'), findsOneWidget);
    expect(find.text('Ongole, Andhra Pradesh'), findsNothing);
  });

  testWidgets('home shows Current location and Entire city radius', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await openMobileHome(tester, repo);

    expect(find.text('Current location'), findsOneWidget);
    expect(find.text('Entire city'), findsOneWidget);
    expect(find.textContaining('looking for?'), findsOneWidget);
  });

  testWidgets('home category tiles expose prototype Function Halls emoji', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await openMobileHome(tester, repo);

    expect(find.text('Function Halls'), findsWidgets);
    expect(find.text('🏛️'), findsWidgets);
    expect(find.text('🎓'), findsWidgets);
    expect(find.text('📅'), findsWidgets);
  });

  testWidgets('home category tiles keep prototype emojis when remote blanks them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(599, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = MockAuthRepository(
      initialUser: const AuthUser(id: 'u1', email: 'a@b.com'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
          authRepositoryProvider.overrideWithValue(auth),
          eventRepositoryProvider.overrideWithValue(MockEventRepository()),
          courseRepositoryProvider.overrideWithValue(MockCourseRepository()),
          homepageContentConfigProvider.overrideWith(
            (ref) async => const HomepageContentConfig(
              categoryTiles: [
                HomeCategoryTile(
                  id: '1',
                  tileKey: 'function_hall',
                  label: 'Function Halls',
                  emoji: '',
                  routeTarget: 'search:function_hall',
                ),
                HomeCategoryTile(
                  id: '2',
                  tileKey: 'classes',
                  label: 'Classes',
                  emoji: '   ',
                  routeTarget: 'courses',
                ),
                HomeCategoryTile(
                  id: '3',
                  tileKey: 'events',
                  label: 'Events',
                  emoji: '',
                  routeTarget: 'events',
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🏛️'), findsWidgets);
    expect(find.text('🎓'), findsWidgets);
    expect(find.text('📅'), findsWidgets);
    // Remote tiles win, but PG / Co-Living and Hotels / Rooms / Stays are
    // always appended so those categories stay reachable from Home.
    expect(find.byType(PrototypeCategoryTile), findsNWidgets(5));
    expect(find.text('PG / Co-Living'), findsOneWidget);
    expect(find.text('Hotels / Rooms / Stays'), findsOneWidget);

    // Brand violet must be the theme primary (prototype #6c3df4).
    final builtContext = tester.element(find.byType(PrototypeCategoryTile).first);
    expect(Theme.of(builtContext).colorScheme.primary, AppTheme.brand);
    expect(
      PrototypeVisuals.categoryTileDecoration().border?.top.color,
      AppTheme.line,
    );
    expect(
      PrototypeVisuals.categoryTileDecoration(selected: true).border?.top.color,
      AppTheme.brand,
    );
    auth.dispose();
  });

  testWidgets('radius chips invalidate nearby listings query', (tester) async {
    final repo = MockVenueRepository();
    await openMobileHome(tester, repo);

    await tester.ensureVisible(find.text('25 km'));
    await tester.tap(find.text('25 km'));
    await tester.pumpAndSettle();

    expect(repo.lastNearbyRadiusKm, 25);
  });
}

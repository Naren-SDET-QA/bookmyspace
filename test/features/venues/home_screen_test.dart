import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
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

    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('The Work Nest'), findsOneWidget);
    expect(find.text('Function Hall'), findsWidgets);

    await tester.tap(find.text('Sunrise Function Hall'));
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
      await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, ${identity.$2}'), findsOneWidget);
      expect(find.text('Welcome to Guest'), findsNothing);
      auth.dispose();
    });
  }

  testWidgets('home greets guest only when unauthenticated', (tester) async {
    final auth = MockAuthRepository();
    await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Guest'), findsOneWidget);
    auth.dispose();
  });

  testWidgets('home updates after restored session', (tester) async {
    final auth = MockAuthRepository();
    await tester.pumpWidget(_app(MockVenueRepository(), authRepo: auth));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Guest'), findsOneWidget);

    auth.restoreSession(
      const AuthUser(
        id: 'restored-id',
        email: 'restored@example.com',
        fullName: 'Restored User',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Restored User'), findsOneWidget);
    expect(find.text('Welcome to Guest'), findsNothing);
    auth.dispose();
  });

  testWidgets('home shows error state and recovers on retry', (tester) async {
    final repo = MockVenueRepository()..failRequests = true;
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsWidgets);

    repo.failRequests = false;
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });

  testWidgets('favourite toggle updates the saved icon', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final saveButtons = find.byIcon(Icons.favorite_outline_rounded);
    expect(saveButtons, findsWidgets);

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
  ]) {
    testWidgets('${route.$1} category opens its listing', (tester) async {
      final repo = MockVenueRepository();
      await openMobileHome(tester, repo);

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
    await tester.tap(find.text('Guntur'));
    await tester.pumpAndSettle();

    expect(find.text('Guntur, Andhra Pradesh'), findsOneWidget);
    expect(find.text('Ongole, Andhra Pradesh'), findsNothing);
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

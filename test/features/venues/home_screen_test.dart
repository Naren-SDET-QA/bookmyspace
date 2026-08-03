import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/router/app_router.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
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
}

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/auth/domain/auth_user.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/courses/presentation/course_providers.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/home/presentation/customer_section_providers.dart';
import 'package:bookmyspace/features/home/presentation/screens/home_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/mock_auth_repository.dart';
import '../courses/mock_course_repository.dart';
import '../events/mock_event_repository.dart';
import 'mock_venue_repository.dart';

Widget _app(
  MockVenueRepository venueRepo, {
  MockAuthRepository? authRepo,
  CustomerSection? section,
}) {
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
    child: MaterialApp(
      home: HomeScreen(initialSection: section),
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
  testWidgets('first home screen shows only the four sections', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Function Halls'), findsWidgets);
    expect(find.text('Lodge / Rooms'), findsOneWidget);
    expect(find.text('PG / Hostels'), findsOneWidget);
    expect(find.text('Institutes / Classes'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsNothing);
    expect(find.text('The Work Nest'), findsNothing);
  });

  testWidgets('function halls section hides lodge, pg and coworking', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.functionHalls));
    await tester.pumpAndSettle();

    expect(find.text('Choose Category'), findsOneWidget);
    expect(find.text('All Halls'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('Crown Lodge Rooms'), findsNothing);
    expect(find.text('Starlight Ladies PG'), findsNothing);
    expect(find.text('The Work Nest'), findsNothing);
  });

  testWidgets('home shows error state after selecting a section', (
    tester,
  ) async {
    final repo = MockVenueRepository()..failRequests = true;
    await tester.pumpWidget(_app(repo, section: CustomerSection.functionHalls));
    await tester.pumpAndSettle();

    expect(find.text('Choose Category'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsWidgets);

    repo.failRequests = false;
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
  });

  testWidgets('lodge section does not show halls or pgs', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.lodgeRooms));
    await tester.pumpAndSettle();

    expect(find.text('Choose Category'), findsOneWidget);
    expect(find.text('All Stays'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Crown Lodge Rooms'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsNothing);
    expect(find.text('Starlight Ladies PG'), findsNothing);
  });
}

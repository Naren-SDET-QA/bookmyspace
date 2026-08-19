import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

Widget _app(
  MockVenueRepository repo, {
  CustomerSection? section,
}) {
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: SearchScreen(
        initialSection: section?.id,
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
  testWidgets('search screen shows only the selected section results', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.functionHalls));
    await tester.pumpAndSettle();

    // Section-scoped chips: halls only.
    expect(find.text('All categories'), findsOneWidget);
    expect(find.textContaining('Marriage Hall'), findsOneWidget);
    // Results contain only halls (Sunrise) and no lodge/PG.
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.text('Crown Lodge Rooms'), findsNothing);
    expect(find.text('Starlight Ladies PG'), findsNothing);
    expect(repo.lastSearchQuery?.sectionId, 'function_halls');
  });

  testWidgets('filter sheet renders section-specific fields for PG', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.pgHostels));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Sharing'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Security Deposit'), findsOneWidget);
    expect(find.text('Rent / Month'), findsOneWidget);
  });

  testWidgets('filter sheet renders section-specific fields for halls', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.functionHalls));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Event Date'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Amenities'), findsOneWidget);
  });

  testWidgets('applying a guests filter scopes results by capacity', (
    tester,
  ) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.functionHalls));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '500'));
    await tester.ensureVisible(find.text('Apply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // Sunrise (capacity 500) survives; nothing else in halls.
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(repo.lastSearchQuery?.minCapacity, 500);
  });

  testWidgets('location bar reflects the shared search area', (tester) async {
    final repo = MockVenueRepository();
    await tester.pumpWidget(_app(repo, section: CustomerSection.lodgeRooms));
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad (Madhapur)'), findsOneWidget);
    expect(find.text('Within 25 km'), findsOneWidget);
    expect(repo.lastSearchQuery?.latitude, isNotNull);
    expect(repo.lastSearchQuery?.maxDistanceKm, 25);
  });
}
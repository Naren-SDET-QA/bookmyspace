import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/owner_venues/presentation/screens/create_venue_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';
import 'mock_owner_venue_repository.dart';

void main() {
  testWidgets('owner create only shows categories from the selected section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ownerRepo = MockOwnerVenueRepository();
    final venueRepo = MockVenueRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownerVenueRepositoryProvider.overrideWithValue(ownerRepo),
          venueRepositoryProvider.overrideWithValue(venueRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: CreateVenueScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('owner_section_function_halls')), findsOneWidget);
    expect(find.byKey(const Key('owner_category_marriage_hall')), findsOneWidget);
    expect(find.byKey(const Key('owner_category_ladies_pg')), findsNothing);

    await tester.tap(find.byKey(const Key('owner_section_pg_hostels')));
    await tester.pump();

    expect(find.byKey(const Key('owner_category_ladies_pg')), findsOneWidget);
    expect(find.byKey(const Key('owner_category_marriage_hall')), findsNothing);
    expect(find.byKey(const Key('owner_category_hotel')), findsNothing);
    expect(find.byKey(const Key('owner_category_coaching')), findsNothing);

    await tester.tap(find.byKey(const Key('owner_section_institutes_classes')));
    await tester.pump();

    expect(find.textContaining('advertising listings only'), findsOneWidget);
    expect(find.byKey(const Key('owner_category_coaching')), findsOneWidget);
    expect(find.byKey(const Key('owner_category_ladies_pg')), findsNothing);
    expect(find.byKey(const Key('owner_category_marriage_hall')), findsNothing);
  });
}

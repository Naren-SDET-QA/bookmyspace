import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/validators/app_validators.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

void main() {
  testWidgets('filter sheet blocks invalid price ranges', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Min price'), '5000');
    await tester.enterText(find.widgetWithText(TextField, 'Max price'), '100');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      AppValidators.priceRange(min: 5000, max: 100),
      isNotNull,
    );
    expect(find.text('Apply'), findsOneWidget);
  });
}

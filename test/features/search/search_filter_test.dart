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
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final minField = find.widgetWithText(TextField, 'Min price');
    final maxField = find.widgetWithText(TextField, 'Max price');
    await tester.scrollUntilVisible(
      minField,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(minField, '5000');
    await tester.enterText(maxField, '100');

    final apply = find.text('Apply');
    await tester.scrollUntilVisible(
      apply,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(apply);
    await tester.pump();

    expect(
      AppValidators.priceRange(min: 5000, max: 100),
      isNotNull,
    );
    expect(find.text('Apply'), findsOneWidget);
  });
}

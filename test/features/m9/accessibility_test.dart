import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/widgets/accessibility.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/venue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

void main() {
  group('MinTouchTarget', () {
    testWidgets('enforces minimum 44x44 size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinTouchTarget(
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );
      final constraints = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.byType(SizedBox).first,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constraints.constraints.minWidth, 44);
      expect(constraints.constraints.minHeight, 44);
    });

    testWidgets('does not enlarge larger widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinTouchTarget(
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(SizedBox).first);
      expect(size.width, 60);
      expect(size.height, 60);
    });
  });

  group('AccessibleInkWell', () {
    testWidgets('renders with onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleInkWell(
              onTap: () => tapped = true,
              semanticsLabel: 'Test button',
              child: const Text('Press me'),
            ),
          ),
        ),
      );
      expect(find.text('Press me'), findsOneWidget);
      await tester.tap(find.text('Press me'));
      expect(tapped, isTrue);
    });
  });

  group('AccessibleIconButton', () {
    testWidgets('renders with tooltip and minimum size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleIconButton(
              icon: Icons.add,
              onPressed: () {},
              tooltip: 'Add item',
              semanticsLabel: 'Add',
            ),
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });

  group('VenueCard semantics', () {
    testWidgets('compact card exposes venue name in semantics', (tester) async {
      final venue = MockVenueRepository.defaultVenues.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isFavoriteProvider(venue.id).overrideWith((ref) => Future.value(false)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VenueCard(venue: venue, compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(VenueCard),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label != null,
          ),
        ),
      );
      expect(semantics.properties.label, '${venue.name}, ${venue.city}');
      expect(semantics.properties.button, isTrue);
    });
  });
}

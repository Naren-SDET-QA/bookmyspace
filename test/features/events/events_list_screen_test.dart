import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/events/presentation/screens/events_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_event_repository.dart';

void main() {
  testWidgets('events discovery filters by search text', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [
        MockEventRepository.sampleEvent(),
        MockEventRepository.sampleEvent(id: 'e2', title: 'Guntur Workshop'),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: EventsListScreen(),
          localizationsDelegates: [
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

    expect(find.text('Hyderabad Music Night'), findsOneWidget);
    expect(find.text('Guntur Workshop'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'guntur');
    await tester.pumpAndSettle();

    expect(find.text('Guntur Workshop'), findsOneWidget);
    expect(find.text('Hyderabad Music Night'), findsNothing);
  });
}

import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/events/domain/event.dart';
import 'package:bookmyspace/features/events/presentation/event_providers.dart';
import 'package:bookmyspace/features/events/presentation/screens/event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_event_repository.dart';

Widget _app(MockEventRepository repo) {
  return ProviderScope(
    overrides: [eventRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      home: EventDetailScreen(eventId: 'e1'),
      localizationsDelegates: [
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
  testWidgets('shows event details and the register button', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad Music Night'), findsOneWidget);
    expect(find.text('Sunrise Function Hall'), findsOneWidget);
    expect(find.textContaining('Register now'), findsOneWidget);
    expect(find.text('200 seats left'), findsOneWidget);
  });

  testWidgets('registering calls the repository', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [MockEventRepository.sampleEvent()];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Register now'));
    await tester.pumpAndSettle();

    expect(repo.lastRegisterEventId, 'e1');
    // After re-fetch the registered state shows the cancel action.
    expect(find.text('Cancel registration'), findsOneWidget);
  });

  testWidgets('registered event shows cancel action and frees the seat', (
    tester,
  ) async {
    final repo = MockEventRepository()
      ..upcoming = [
        MockEventRepository.sampleEvent(
          userRegistered: true,
          registeredCount: 5,
        ),
      ];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Cancel registration'), findsOneWidget);

    await tester.tap(find.text('Cancel registration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(repo.lastCancelEventId, 'e1');
    expect(find.textContaining('Register now'), findsOneWidget);
  });

  testWidgets('a sold-out event disables registration', (tester) async {
    final repo = MockEventRepository()
      ..upcoming = [
        MockEventRepository.sampleEvent(capacity: 2, registeredCount: 2),
      ];
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Sold out'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  test('seats left reflects live counts', () {
    final event = Event.fromJson({
      'title': 'e',
      'starts_at': '2026-08-17T18:00:00Z',
      'ends_at': '2026-08-17T22:00:00Z',
      'capacity': 10,
      'registered_count': 3,
    });
    expect(event.seatsLeft, 7);
    expect(event.userRegistered, isFalse);
  });
}

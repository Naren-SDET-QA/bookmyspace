import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/offline/offline_providers.dart';
import 'package:bookmyspace/core/offline/offline_store.dart';
import 'package:bookmyspace/features/search/domain/recent_search.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../venues/mock_venue_repository.dart';

Widget _searchApp(OfflineStore store) {
  return ProviderScope(
    overrides: [
      venueRepositoryProvider.overrideWithValue(MockVenueRepository()),
      offlineStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(
      home: SearchScreen(),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('RecentSearchStore', () {
    test('saves and reloads from the same OfflineStore', () async {
      final memory = MemoryOfflineStore();
      final now = DateTime(2026, 9, 1, 12);
      await RecentSearchStore(memory).add('Halls', now: now);

      final reloaded = await RecentSearchStore(memory).load();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.query, 'Halls');
      expect(reloaded.single.searchedAt, now);
    });

    test('orders newest first', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      final now = DateTime(2026, 9, 1, 12);
      await store.add('Halls', now: now);
      await store.add('PG', now: now.add(const Duration(minutes: 1)));
      await store.add('Hotels', now: now.add(const Duration(minutes: 2)));
      expect((await store.load()).map((item) => item.query), [
        'Hotels',
        'PG',
        'Halls',
      ]);
    });

    test('duplicate queries move to the front and keep one entry', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      final now = DateTime(2026, 9, 1, 12);
      await store.add('Halls', now: now);
      await store.add('PG', now: now.add(const Duration(minutes: 1)));
      await store.add('halls', now: now.add(const Duration(minutes: 2)));
      final items = await store.load();
      expect(items.map((item) => item.query), ['halls', 'PG']);
    });

    test('deletes an individual search', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      await store.add('Halls');
      await store.add('PG');
      await store.remove('Halls');
      final items = await store.load();
      expect(items.map((item) => item.query), ['PG']);
    });

    test('clear all removes persisted history', () async {
      final memory = MemoryOfflineStore();
      final store = RecentSearchStore(memory);
      await store.add('Halls');
      await store.clear();
      expect(await store.load(), isEmpty);
      expect(
        memory.snapshot.containsKey(RecentSearchStore.storageKey),
        isFalse,
      );
      expect(await RecentSearchStore(memory).load(), isEmpty);
    });

    test('caps history at the legacy maximum of 10', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      final now = DateTime(2026, 9, 1, 12);
      for (var i = 1; i <= 12; i++) {
        await store.add('query$i', now: now.add(Duration(minutes: i)));
      }
      final items = await store.load();
      expect(items, hasLength(RecentSearchStore.maxHistory));
      expect(items.first.query, 'query12');
      expect(items.last.query, 'query3');
      expect(items.any((item) => item.query == 'query1'), isFalse);
      expect(items.any((item) => item.query == 'query2'), isFalse);
    });

    test('empty store has no recent searches', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      expect(await store.load(), isEmpty);
    });

    test('ignores blank and one-character queries', () async {
      final store = RecentSearchStore(MemoryOfflineStore());
      await store.add(' ');
      await store.add('a');
      expect(await store.load(), isEmpty);
    });
  });

  group('SearchScreen recent searches', () {
    testWidgets('shows empty state when history is empty', (tester) async {
      await tester.pumpWidget(_searchApp(MemoryOfflineStore()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recent_searches_empty')), findsOneWidget);
      expect(find.text('No recent searches'), findsOneWidget);
      expect(find.byKey(const Key('recent_searches')), findsNothing);
    });

    testWidgets('saves a submitted query and reloads chips', (tester) async {
      final memory = MemoryOfflineStore();
      await tester.pumpWidget(_searchApp(memory));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Halls');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recent_search_chip_Halls')), findsOneWidget);
      expect(find.byKey(const Key('recent_searches_empty')), findsNothing);

      await tester.pumpWidget(_searchApp(memory));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recent_search_chip_Halls')), findsOneWidget);
    });

    testWidgets('selecting a recent search fills the query', (tester) async {
      final memory = MemoryOfflineStore();
      await RecentSearchStore(
        memory,
      ).add('Hotels', now: DateTime(2026, 9, 1, 12));
      await tester.pumpWidget(_searchApp(memory));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recent_search_chip_Hotels')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Hotels'), findsOneWidget);
    });

    testWidgets('deletes one search and clear-all restores empty state', (
      tester,
    ) async {
      final memory = MemoryOfflineStore();
      final store = RecentSearchStore(memory);
      final now = DateTime(2026, 9, 1, 12);
      await store.add('Halls', now: now);
      await store.add('PG', now: now.add(const Duration(minutes: 1)));

      await tester.pumpWidget(_searchApp(memory));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recent_search_chip_Halls')), findsOneWidget);
      expect(find.byKey(const Key('recent_search_chip_PG')), findsOneWidget);

      await tester.tap(find.byKey(const Key('recent_search_delete_Halls')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recent_search_chip_Halls')), findsNothing);
      expect(find.byKey(const Key('recent_search_chip_PG')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear_all_recent_searches')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recent_searches_empty')), findsOneWidget);
      expect(find.byKey(const Key('recent_searches')), findsNothing);
    });
  });
}

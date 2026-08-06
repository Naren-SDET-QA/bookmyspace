import 'package:bookmyspace/core/widgets/empty_state.dart';
import 'package:bookmyspace/core/widgets/error_view.dart';
import 'package:bookmyspace/features/accommodations/presentation/screens/accommodation_list_screen.dart';
import 'package:bookmyspace/features/courses/presentation/screens/courses_list_screen.dart';
import 'package:bookmyspace/features/events/presentation/screens/events_list_screen.dart';
import 'package:bookmyspace/features/meeting_rooms/presentation/screens/meeting_rooms_screen.dart';
import 'package:bookmyspace/features/search/presentation/screens/search_screen.dart';
import 'package:bookmyspace/features/sports/presentation/screens/sports_screens.dart';
import 'package:bookmyspace/features/venues/presentation/screens/venue_details_screen.dart';
import 'package:bookmyspace/features/venues/presentation/widgets/venue_card.dart';
import 'package:bookmyspace/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Pumps frames until [ready] is true or [timeout] elapses.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 35),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (ready()) return;
  }
  throw StateError('Timed out waiting for condition');
}

/// Pumps frames for a fixed duration (for animations / splash).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Waits until the loading spinner disappears (data arrived or errored).
Future<void> waitForLoad(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
  );
}

/// Navigates home from wherever we are (bottom-nav tab or AppBar back).
Future<void> backToHome(WidgetTester tester) async {
  final homeTab = find.text('Home');
  if (homeTab.evaluate().isNotEmpty) {
    await tester.tap(homeTab);
  } else {
    await tester.pageBack();
  }
  await pumpUntil(
    tester,
    () => find.text('Function Halls').evaluate().isNotEmpty,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 2: all customer categories reachable & functional',
      (tester) async {
    final results = <String, String>{};
    void report(String name, bool ok, [String detail = '']) {
      results[name] = ok ? 'PASS' : 'FAIL';
      debugPrint('PHASE2|$name|${ok ? "PASS" : "FAIL"}|$detail');
    }

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        report(name, true);
      } catch (e) {
        report(name, false, e.toString());
      }
    }

    // ---------------------------------------------------------------
    // 1. Boot: splash -> onboarding -> test login -> home
    // ---------------------------------------------------------------
    await app.main();
    await pumpUntil(
      tester,
      () => find.text('Get started').evaluate().isNotEmpty ||
          find.text('Skip').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 40),
    );
    // Skip onboarding (Skip is always visible; Get started is page 3 only).
    final skip = find.text('Skip');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
    } else {
      await tester.tap(find.text('Get started'));
    }
    await pumpFor(tester, const Duration(seconds: 2));

    // Login screen (redirect) with TEST MODE one-tap login.
    await pumpUntil(
      tester,
      () =>
          find.text('Customer Test Login').evaluate().isNotEmpty ||
          find.text('Welcome back 👋').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 25),
    );
    final testLogin = find.text('Customer Test Login');
    if (testLogin.evaluate().isEmpty) {
      report('LOGIN', false, 'TEST MODE login buttons not visible');
    } else {
      await tester.tap(testLogin);
      await pumpUntil(
        tester,
        () => find.text('Function Halls').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
      );
      report('LOGIN', true);
    }

    // ---------------------------------------------------------------
    // 2. Home tiles present
    // ---------------------------------------------------------------
    final expectedTiles = [
      'Function Halls',
      'Classes',
      'Events',
      'Meetings',
      'Conferences',
      'Parties',
      'Sports',
      'Shows',
      'PG / Co-Living',
      'Hotels / Rooms / Stays',
    ];
    final missingTiles = <String>[
      for (final t in expectedTiles)
        if (find.text(t).evaluate().isEmpty) t,
    ];
    report('HOME_TILES', missingTiles.isEmpty, missingTiles.join(','));

    // ---------------------------------------------------------------
    // 3. Category walkthrough
    // ---------------------------------------------------------------
    Future<void> verifyListLoaded(
      String category,
      Type screenType,
      List<String> emptyStateTexts,
    ) async {
      // Tile may need scrolling into view.
      await tester.ensureVisible(find.text(category));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(category));
      await pumpUntil(
        tester,
        () => find.byType(screenType).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      final hasError = find.byType(ErrorView).evaluate().isNotEmpty;
      if (hasError) {
        throw StateError('ErrorView shown for $category');
      }
      final empty = <String>[
        for (final t in emptyStateTexts)
          if (find.text(t).evaluate().isNotEmpty) t,
      ];
      if (empty.isEmpty) {
        report(
          category,
          true,
          'list rendered (items or empty state)',
        );
      } else {
        report(category, true, 'EMPTY_STATE: ${empty.join('/')}');
      }
      await backToHome(tester);
    }

    // Function Halls -> Explore/search tab.
    await step('FUNCTION_HALLS', () async {
      await tester.ensureVisible(find.text('Function Halls'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Function Halls'));
      await pumpUntil(
        tester,
        () => find.byType(SearchScreen).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      if (find.byType(ErrorView).evaluate().isNotEmpty) {
        throw StateError('Search error view');
      }
      final count = find.byType(VenueCard).evaluate().length;
      report('FUNCTION_HALLS', true, 'venues rendered: $count');
      await backToHome(tester);
    });

    await step('MEETINGS', () => verifyListLoaded('Meetings',
        MeetingRoomsScreen, ['No meeting rooms', 'Nothing here']));

    await step('SPORTS', () => verifyListLoaded(
        'Sports', SportsVenuesScreen, ['No sports venues', 'Nothing here']));

    await step('CLASSES', () => verifyListLoaded(
        'Classes', CoursesListScreen, ['No courses', 'Nothing here']));

    await step('EVENTS', () => verifyListLoaded(
        'Events', EventsListScreen, ['No events', 'Nothing here']));

    // Conferences / Parties / Shows all route to the events list.
    for (final tile in ['Conferences', 'Parties', 'Shows']) {
      await step(tile.toUpperCase(), () async {
        await tester.ensureVisible(find.text(tile));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(tile));
        await pumpUntil(
          tester,
          () => find.byType(EventsListScreen).evaluate().isNotEmpty,
        );
        await waitForLoad(tester);
        report(tile.toUpperCase(), true, 'routes to Events list');
        await backToHome(tester);
      });
    }

    // PG / Co-Living -> dedicated accommodation list.
    await step('PG', () async {
      await tester.ensureVisible(find.text('PG / Co-Living'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('PG / Co-Living'));
      await pumpUntil(
        tester,
        () => find.byType(AccommodationListScreen).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      if (find.byType(ErrorView).evaluate().isNotEmpty) {
        throw StateError('PG error view');
      }
      final empty = find.byType(EmptyState).evaluate().isNotEmpty;
      report('PG', true, empty ? 'EMPTY_STATE (no data)' : 'items rendered');
      await backToHome(tester);
    });

    // Hotels / Rooms / Stays -> dedicated accommodation list.
    await step('STAYS', () async {
      await tester.ensureVisible(find.text('Hotels / Rooms / Stays'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Hotels / Rooms / Stays'));
      await pumpUntil(
        tester,
        () => find.byType(AccommodationListScreen).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      if (find.byType(ErrorView).evaluate().isNotEmpty) {
        throw StateError('Stays error view');
      }
      final empty = find.byType(EmptyState).evaluate().isNotEmpty;
      report('STAYS', true, empty ? 'EMPTY_STATE (no data)' : 'items rendered');
      await backToHome(tester);
    });

    // ---------------------------------------------------------------
    // 4. Function hall details + booking entry (no confirmation)
    // ---------------------------------------------------------------
    await step('DETAILS_BOOKING_ENTRY', () async {
      await tester.ensureVisible(find.text('Function Halls'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Function Halls'));
      await pumpUntil(
        tester,
        () => find.byType(SearchScreen).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      final cards = find.byType(VenueCard);
      if (cards.evaluate().isEmpty) {
        report('DETAILS_BOOKING_ENTRY', false, 'no venue results to open');
        await backToHome(tester);
        return;
      }
      await tester.tap(cards.first);
      await pumpUntil(
        tester,
        () => find.byType(VenueDetailsScreen).evaluate().isNotEmpty,
      );
      await waitForLoad(tester);
      final hasBookNow =
          find.textContaining('Book now').evaluate().isNotEmpty ||
          find.text('Request Booking').evaluate().isNotEmpty;
      final hasAbout =
          find.text('About this venue').evaluate().isNotEmpty;
      final hasMap =
          find.text('View on map').evaluate().isNotEmpty;
      report(
        'DETAILS_BOOKING_ENTRY',
        hasBookNow && hasAbout,
        'bookNow=$hasBookNow about=$hasAbout map=$hasMap',
      );
      await tester.pageBack();
      await pumpUntil(
        tester,
        () => find.byType(SearchScreen).evaluate().isNotEmpty,
      );
      await backToHome(tester);
    });

    // ---------------------------------------------------------------
    // 5. Saved tab + bottom nav
    // ---------------------------------------------------------------
    await step('SAVED_TAB', () async {
      await tester.tap(find.text('Saved'));
      await pumpUntil(
        tester,
        () =>
            find.text('Saved 💜').evaluate().isNotEmpty ||
            find.byType(EmptyState).evaluate().isNotEmpty,
      );
      report('SAVED_TAB', true, 'Saved screen rendered');
      await backToHome(tester);
    });

    // ---------------------------------------------------------------
    // Summary
    // ---------------------------------------------------------------
    final failed = results.entries.where((e) => e.value == 'FAIL').toList();
    debugPrint('PHASE2|SUMMARY|failing=${failed.length}/${results.length}');
    for (final f in failed) {
      debugPrint('PHASE2|FAILED|${f.key}');
    }
    expect(failed, isEmpty,
        reason: 'Categories that failed: ${failed.map((e) => e.key).join(', ')}');
  });
}

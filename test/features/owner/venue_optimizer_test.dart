import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:bookmyspace/features/owner/domain/venue_optimizer.dart';
import 'package:bookmyspace/features/owner/presentation/screens/venue_optimizer_screen.dart';
import 'package:bookmyspace/features/owner_bookings/presentation/owner_booking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../owner_bookings/mock_owner_booking_repository.dart';

Booking _booking({
  required String id,
  required BookingStatus status,
  required String start,
  String venue = 'Hall A',
  double total = 1000,
  DateTime? date,
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-$id',
    venueId: venue,
    slotId: 's1',
    bookDate: date ?? DateTime(2026, 8, 20),
    startTime: start,
    endTime: '19:00:00',
    status: status,
    amount: total,
    taxAmount: 0,
    totalAmount: total,
    venueName: venue,
  );
}

Widget _app(MockOwnerBookingRepository repo) {
  return ProviderScope(
    overrides: [ownerBookingRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: VenueOptimizerScreen(),
    ),
  );
}

void main() {
  final now = DateTime(2026, 8, 30);

  test('metrics: occupancy, revenue and venue comparison', () {
    final report = VenueOptimizerEngine.build(
      now: now,
      bookings: [
        _booking(id: '1', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(id: '2', status: BookingStatus.confirmed, start: '18:30:00'),
        _booking(id: '3', status: BookingStatus.cancelled, start: '10:00:00'),
        _booking(
          id: '4',
          status: BookingStatus.confirmed,
          start: '18:00:00',
          venue: 'Hall B',
          total: 500,
        ),
      ],
    );
    expect(report.confirmedCount, 3);
    expect(report.cancelledCount, 1);
    expect(report.occupancyPercent, 75);
    expect(report.revenue, 2500);
    expect(
      report.hourly.any((bucket) => bucket.isPeak && bucket.hour == 18),
      isTrue,
    );
    expect(report.venues, hasLength(2));
    expect(report.venues.first.venueName, 'Hall A');
    expect(report.venues.first.revenue, 2000);
  });

  test('owner data isolation ignores other venues', () {
    final report = VenueOptimizerEngine.build(
      now: now,
      venueIds: {'Hall A'},
      bookings: [
        _booking(id: '1', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(
          id: '2',
          status: BookingStatus.confirmed,
          start: '10:00:00',
          venue: 'Hall B',
          total: 9000,
        ),
      ],
    );
    expect(report.confirmedCount, 1);
    expect(report.venues.map((v) => v.venueId), ['Hall A']);
    expect(report.revenue, 1000);
  });

  test('empty data yields the empty report', () {
    final report = VenueOptimizerEngine.build(now: now, bookings: const []);
    expect(report.isEmpty, isTrue);
    expect(report.recommendations.single.title, 'No recent bookings');
  });

  test('date filtering keeps only bookings in the selected range', () {
    final report = VenueOptimizerEngine.build(
      now: now,
      start: DateTime(2026, 8, 18),
      end: DateTime(2026, 8, 21),
      bookings: [
        _booking(id: 'in', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(
          id: 'out',
          status: BookingStatus.confirmed,
          start: '18:00:00',
          date: DateTime(2026, 7, 1),
        ),
      ],
    );
    expect(report.confirmedCount, 1);
    expect(report.daily.single.day, DateTime(2026, 8, 20));
  });

  test('recommendation logic flags peak, off-peak and cancellations', () {
    final report = VenueOptimizerEngine.build(
      now: now,
      bookings: [
        _booking(id: '1', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(id: '2', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(id: '3', status: BookingStatus.cancelled, start: '10:00:00'),
      ],
    );
    expect(
      report.recommendations.any((item) => item.title.contains('Peak demand')),
      isTrue,
    );
    expect(
      report.recommendations.any((item) => item.title.contains('off-peak')),
      isTrue,
    );
    expect(
      report.recommendations.any(
        (item) => item.title.contains('Cancellations'),
      ),
      isTrue,
    );
  });

  test('prior-period trend compares bookings and revenue', () {
    final report = VenueOptimizerEngine.build(
      now: now,
      start: DateTime(2026, 8, 16),
      end: DateTime(2026, 8, 30),
      bookings: [
        _booking(id: 'now', status: BookingStatus.confirmed, start: '18:00:00'),
        _booking(
          id: 'prior',
          status: BookingStatus.confirmed,
          start: '18:00:00',
          date: DateTime(2026, 8, 1),
          total: 400,
        ),
      ],
    );
    expect(report.confirmedCount, 1);
    expect(report.trend.bookingDelta, 0);
    expect(report.trend.revenueDelta, 600);
  });

  testWidgets('optimizer dashboard renders live report', (tester) async {
    final repo = MockOwnerBookingRepository(
      bookings: [
        _booking(
          id: '1',
          status: BookingStatus.confirmed,
          start: '18:00:00',
          date: DateTime.now(),
        ),
      ],
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('venue_optimizer_dashboard')), findsOneWidget);
    expect(find.byKey(const Key('optimizer_trend')), findsOneWidget);
    expect(find.text('Occupancy'), findsOneWidget);
    expect(find.byKey(const Key('optimizer_venue_compare')), findsOneWidget);
    expect(find.text('Hall A'), findsOneWidget);
  });

  testWidgets('empty owner bookings show the empty state', (tester) async {
    await tester.pumpWidget(_app(MockOwnerBookingRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('optimizer_empty')), findsOneWidget);
    expect(find.text('No optimizer data'), findsOneWidget);
  });

  testWidgets('date range chips are selectable', (tester) async {
    await tester.pumpWidget(
      _app(
        MockOwnerBookingRepository(
          bookings: [
            _booking(
              id: '1',
              status: BookingStatus.confirmed,
              start: '18:00:00',
              date: DateTime.now(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('optimizer_range_7')));
    await tester.pump();
    final chip = tester.widget<ChoiceChip>(
      find.byKey(const Key('optimizer_range_7')),
    );
    expect(chip.selected, isTrue);
  });
}

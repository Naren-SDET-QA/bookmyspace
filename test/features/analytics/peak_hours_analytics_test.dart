import 'package:bookmyspace/features/analytics/domain/peak_hours_analytics.dart';
import 'package:bookmyspace/features/analytics/presentation/widgets/peak_hours_chart.dart';
import 'package:bookmyspace/features/booking/domain/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Booking _booking({
  required String id,
  required DateTime date,
  required String start,
  BookingStatus status = BookingStatus.confirmed,
  String venueId = 'venue-a',
}) {
  return Booking(
    id: id,
    bookingRef: 'BMS-$id',
    venueId: venueId,
    slotId: 's1',
    bookDate: date,
    startTime: start,
    endTime: '19:00:00',
    status: status,
    amount: 1000,
    taxAmount: 0,
    totalAmount: 1000,
    venueName: venueId,
  );
}

void main() {
  final friday = DateTime(2026, 2, 6);
  final saturday = DateTime(2026, 2, 7);

  group('PeakHoursCalculator', () {
    test('aggregates confirmed bookings by hour', () {
      final report = PeakHoursCalculator.build(
        bookings: [
          _booking(id: '1', date: friday, start: '18:00:00'),
          _booking(id: '2', date: friday, start: '18:30:00'),
          _booking(id: '3', date: friday, start: '10:00:00'),
        ],
        start: friday,
        end: friday,
      );
      expect(report.confirmedCount, 3);
      expect(report.hourly, hasLength(24));
      expect(report.hourly[18].bookingCount, 2);
      expect(report.hourly[10].bookingCount, 1);
      expect(report.hourly[18].occupancyPercent, closeTo(66.67, 0.1));
    });

    test('marks the busiest hour as peak', () {
      final report = PeakHoursCalculator.build(
        bookings: [
          _booking(id: '1', date: friday, start: '18:00:00'),
          _booking(id: '2', date: friday, start: '18:15:00'),
          _booking(id: '3', date: friday, start: '18:45:00'),
          _booking(id: '4', date: friday, start: '10:00:00'),
        ],
        start: friday,
        end: friday,
      );
      expect(report.peakHour?.hour, 18);
      expect(report.hourly[18].isPeak, isTrue);
      expect(report.hourly[10].isPeak, isFalse);
      expect(report.quietHour?.hour, isNot(18));
    });

    test('empty and cancelled bookings produce no peak hours', () {
      final empty = PeakHoursCalculator.build(
        bookings: const [],
        start: friday,
        end: friday,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.hourly, isEmpty);

      final cancelled = PeakHoursCalculator.build(
        bookings: [
          _booking(
            id: '1',
            date: friday,
            start: '18:00:00',
            status: BookingStatus.cancelled,
          ),
        ],
        start: friday,
        end: friday,
      );
      expect(cancelled.isEmpty, isTrue);
    });

    test('date filtering excludes bookings outside the range', () {
      final report = PeakHoursCalculator.build(
        bookings: [
          _booking(id: 'in', date: friday, start: '18:00:00'),
          _booking(id: 'out', date: DateTime(2026, 1, 1), start: '18:00:00'),
        ],
        start: friday,
        end: friday,
      );
      expect(report.confirmedCount, 1);
      expect(report.hourly[18].bookingCount, 1);
    });

    test('weekday and weekend filters split occupancy', () {
      final bookings = [
        _booking(id: 'w', date: friday, start: '10:00:00'),
        _booking(id: 's', date: saturday, start: '18:00:00'),
      ];
      final weekdays = PeakHoursCalculator.build(
        bookings: bookings,
        start: friday,
        end: saturday,
        dayFilter: PeakHoursDayFilter.weekday,
      );
      expect(weekdays.confirmedCount, 1);
      expect(weekdays.peakHour?.hour, 10);

      final weekends = PeakHoursCalculator.build(
        bookings: bookings,
        start: friday,
        end: saturday,
        dayFilter: PeakHoursDayFilter.weekend,
      );
      expect(weekends.confirmedCount, 1);
      expect(weekends.peakHour?.hour, 18);
    });

    test('owner venue isolation ignores other listings', () {
      final report = PeakHoursCalculator.build(
        bookings: [
          _booking(id: 'mine', date: friday, start: '18:00:00', venueId: 'a'),
          _booking(id: 'other', date: friday, start: '10:00:00', venueId: 'b'),
        ],
        start: friday,
        end: friday,
        venueIds: {'a'},
      );
      expect(report.confirmedCount, 1);
      expect(report.hourly[18].bookingCount, 1);
      expect(report.hourly[10].bookingCount, 0);
    });
  });

  group('PeakHoursChart', () {
    testWidgets('renders hourly bars and the peak label', (tester) async {
      final report = PeakHoursCalculator.build(
        bookings: [
          _booking(id: '1', date: friday, start: '18:00:00'),
          _booking(id: '2', date: friday, start: '18:30:00'),
        ],
        start: friday,
        end: friday,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeakHoursChart(
              report: report,
              dayFilter: PeakHoursDayFilter.all,
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('peak_hours_chart_card')), findsOneWidget);
      expect(find.byKey(const Key('peak_hours_line_canvas')), findsOneWidget);
      expect(find.byKey(const Key('peak_hours_peak_label')), findsOneWidget);
      expect(find.textContaining('6:00 PM'), findsWidgets);
    });

    testWidgets('shows empty state when there is no hourly data', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeakHoursChart(
              report: PeakHoursReport.empty(),
              dayFilter: PeakHoursDayFilter.all,
              onFilterChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('peak_hours_empty')), findsOneWidget);
      expect(find.text('No hourly pattern yet'), findsOneWidget);
      expect(find.byKey(const Key('peak_hours_line_canvas')), findsNothing);
    });
  });
}

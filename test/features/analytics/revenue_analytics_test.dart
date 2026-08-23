import 'package:bookmyspace/features/analytics/domain/revenue_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = [
    AnalyticsBookingRecord(
      id: '1',
      date: DateTime(2026, 2, 2),
      amount: 100,
      paymentCaptured: true,
      category: 'Function Hall',
      venue: 'A',
    ),
    AnalyticsBookingRecord(
      id: '2',
      date: DateTime(2026, 2, 3),
      amount: 200,
      paymentCaptured: true,
      category: 'Function Hall',
      venue: 'A',
      refundAmount: 50,
    ),
    AnalyticsBookingRecord(
      id: '3',
      date: DateTime(2026, 2, 4),
      amount: 300,
      paymentCaptured: false,
      category: 'Meeting Room',
      venue: 'B',
      cancelled: true,
    ),
  ];

  test('daily, weekly and monthly revenue aggregation excludes cancelled', () {
    final result = RevenueAnalyticsCalculator.calculate(
      records,
      DateTime(2026, 2, 1),
      DateTime(2026, 2, 28),
    );
    expect(result.successfulBookings, 2);
    expect(result.totalRevenue, 300);
    expect(result.refundAmount, 50);
    expect(result.netRevenue, 250);
    expect(result.dailyRevenue, hasLength(2));
    expect(result.weeklyRevenue, isNotEmpty);
    expect(result.monthlyRevenue.single.value, 300);
  });

  test('custom date filtering and category/venue aggregation work', () {
    final result = RevenueAnalyticsCalculator.calculate(
      records,
      DateTime(2026, 2, 3),
      DateTime(2026, 2, 3),
    );
    expect(result.successfulBookings, 1);
    expect(result.categoryRevenue.single.label, 'Function Hall');
    expect(result.venueRevenue.single.label, 'A');
  });

  test('empty and large inputs remain bounded in chart output', () {
    final empty = RevenueAnalyticsCalculator.calculate(
      const [],
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 31),
    );
    expect(empty.isEmpty, isTrue);
    final many = [
      for (var i = 0; i < 5000; i++)
        AnalyticsBookingRecord(
          id: '$i',
          date: DateTime(2026, 1, 1),
          amount: 1,
          paymentCaptured: true,
          category: 'Hall',
          venue: 'Venue $i',
        ),
    ];
    final result = RevenueAnalyticsCalculator.calculate(
      many,
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 1),
    );
    expect(result.dailyRevenue, hasLength(1));
  });
}

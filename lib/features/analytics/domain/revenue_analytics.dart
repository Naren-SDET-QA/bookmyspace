class AnalyticsBookingRecord {
  const AnalyticsBookingRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.paymentCaptured,
    required this.category,
    required this.venue,
    this.refundAmount = 0,
    this.cancelled = false,
  });

  final String id;
  final DateTime date;
  final double amount;
  final bool paymentCaptured;
  final String category;
  final String venue;
  final double refundAmount;
  final bool cancelled;
}

class AnalyticsPoint {
  const AnalyticsPoint(this.label, this.value, this.count);
  final String label;
  final double value;
  final int count;
}

class AnalyticsBreakdown {
  const AnalyticsBreakdown(this.label, this.value, this.count);
  final String label;
  final double value;
  final int count;
}

class RevenueAnalytics {
  const RevenueAnalytics({
    required this.totalRevenue,
    required this.successfulBookings,
    required this.cancelledBookings,
    required this.refundAmount,
    required this.netRevenue,
    required this.averageBookingValue,
    required this.dailyRevenue,
    required this.weeklyRevenue,
    required this.monthlyRevenue,
    required this.bookingTrend,
    required this.categoryRevenue,
    required this.venueRevenue,
  });

  factory RevenueAnalytics.empty() => const RevenueAnalytics(
    totalRevenue: 0,
    successfulBookings: 0,
    cancelledBookings: 0,
    refundAmount: 0,
    netRevenue: 0,
    averageBookingValue: 0,
    dailyRevenue: [],
    weeklyRevenue: [],
    monthlyRevenue: [],
    bookingTrend: [],
    categoryRevenue: [],
    venueRevenue: [],
  );

  final double totalRevenue;
  final int successfulBookings;
  final int cancelledBookings;
  final double refundAmount;
  final double netRevenue;
  final double averageBookingValue;
  final List<AnalyticsPoint> dailyRevenue;
  final List<AnalyticsPoint> weeklyRevenue;
  final List<AnalyticsPoint> monthlyRevenue;
  final List<AnalyticsPoint> bookingTrend;
  final List<AnalyticsBreakdown> categoryRevenue;
  final List<AnalyticsBreakdown> venueRevenue;

  bool get isEmpty => successfulBookings == 0 && cancelledBookings == 0;

  factory RevenueAnalytics.fromJson(Map<String, dynamic> json) {
    List<AnalyticsPoint> points(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AnalyticsPoint(
                '${row['label'] ?? ''}',
                (row['value'] as num?)?.toDouble() ?? 0,
                (row['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false);
    List<AnalyticsBreakdown> breakdown(String key) =>
        ((json[key] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => AnalyticsBreakdown(
                '${row['label'] ?? ''}',
                (row['value'] as num?)?.toDouble() ?? 0,
                (row['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(growable: false);
    return RevenueAnalytics(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      successfulBookings: (json['successful_bookings'] as num?)?.toInt() ?? 0,
      cancelledBookings: (json['cancelled_bookings'] as num?)?.toInt() ?? 0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      netRevenue: (json['net_revenue'] as num?)?.toDouble() ?? 0,
      averageBookingValue:
          (json['average_booking_value'] as num?)?.toDouble() ?? 0,
      dailyRevenue: points('daily_revenue'),
      weeklyRevenue: points('weekly_revenue'),
      monthlyRevenue: points('monthly_revenue'),
      bookingTrend: points('booking_trend'),
      categoryRevenue: breakdown('category_revenue'),
      venueRevenue: breakdown('venue_revenue'),
    );
  }
}

class RevenueAnalyticsCalculator {
  static RevenueAnalytics calculate(
    List<AnalyticsBookingRecord> records,
    DateTime start,
    DateTime end,
  ) {
    final selected = records.where((record) {
      final day = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
          !day.isAfter(DateTime(end.year, end.month, end.day));
    });
    final successful = selected
        .where((record) => record.paymentCaptured && !record.cancelled)
        .toList();
    final refund = successful.fold<double>(
      0,
      (sum, row) => sum + row.refundAmount,
    );
    List<AnalyticsPoint> points(String Function(AnalyticsBookingRecord) key) {
      final grouped = <String, List<AnalyticsBookingRecord>>{};
      for (final row in successful) {
        grouped.putIfAbsent(key(row), () => []).add(row);
      }
      return grouped.entries
          .map(
            (entry) => AnalyticsPoint(
              entry.key,
              entry.value.fold(0, (sum, row) => sum + row.amount),
              entry.value.length,
            ),
          )
          .toList(growable: false);
    }

    final daily = points((row) => _day(row.date));
    final weekly = points((row) => _week(row.date));
    final monthly = points(
      (row) => '${row.date.year}-${row.date.month.toString().padLeft(2, '0')}',
    );
    List<AnalyticsBreakdown> breakdown(
      String Function(AnalyticsBookingRecord) key,
    ) {
      final grouped = <String, List<AnalyticsBookingRecord>>{};
      for (final row in successful)
        grouped.putIfAbsent(key(row), () => []).add(row);
      return grouped.entries
          .map(
            (entry) => AnalyticsBreakdown(
              entry.key,
              entry.value.fold(0, (sum, row) => sum + row.amount),
              entry.value.length,
            ),
          )
          .toList(growable: false);
    }

    final total = successful.fold<double>(0, (sum, row) => sum + row.amount);
    return RevenueAnalytics(
      totalRevenue: total,
      successfulBookings: successful.length,
      cancelledBookings: selected.where((row) => row.cancelled).length,
      refundAmount: refund,
      netRevenue: total - refund,
      averageBookingValue: successful.isEmpty ? 0 : total / successful.length,
      dailyRevenue: daily,
      weeklyRevenue: weekly,
      monthlyRevenue: monthly,
      bookingTrend: daily,
      categoryRevenue: breakdown((row) => row.category),
      venueRevenue: breakdown((row) => row.venue),
    );
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _week(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return _day(monday);
  }
}

import '../../booking/domain/booking.dart';

class OptimizerHourBucket {
  const OptimizerHourBucket({
    required this.hour,
    required this.label,
    required this.bookingCount,
    required this.sharePercent,
    required this.isPeak,
  });

  final int hour;
  final String label;
  final int bookingCount;
  final int sharePercent;
  final bool isPeak;
}

class OptimizerVenueStat {
  const OptimizerVenueStat({
    required this.venueId,
    required this.venueName,
    required this.confirmedCount,
    required this.cancelledCount,
    required this.revenue,
  });

  final String venueId;
  final String venueName;
  final int confirmedCount;
  final int cancelledCount;
  final double revenue;

  int get occupancyPercent {
    final total = confirmedCount + cancelledCount;
    if (total <= 0) return 0;
    return ((confirmedCount / total) * 100).round();
  }
}

class OptimizerRecommendation {
  const OptimizerRecommendation({
    required this.title,
    required this.detail,
    this.priority = 'medium',
  });

  final String title;
  final String detail;
  final String priority;
}

class OptimizerDayPoint {
  const OptimizerDayPoint({required this.day, required this.confirmedCount});

  final DateTime day;
  final int confirmedCount;
}

class OptimizerTrend {
  const OptimizerTrend({
    required this.bookingDelta,
    required this.revenueDelta,
    required this.occupancyDelta,
  });

  const OptimizerTrend.zero()
    : bookingDelta = 0,
      revenueDelta = 0,
      occupancyDelta = 0;

  final int bookingDelta;
  final double revenueDelta;
  final int occupancyDelta;
}

class VenueOptimizerReport {
  const VenueOptimizerReport({
    required this.confirmedCount,
    required this.cancelledCount,
    required this.occupancyPercent,
    required this.revenue,
    required this.hourly,
    required this.venues,
    required this.recommendations,
    this.daily = const [],
    this.trend = const OptimizerTrend.zero(),
  });

  factory VenueOptimizerReport.empty() => const VenueOptimizerReport(
    confirmedCount: 0,
    cancelledCount: 0,
    occupancyPercent: 0,
    revenue: 0,
    hourly: [],
    venues: [],
    daily: [],
    recommendations: [
      OptimizerRecommendation(
        title: 'No recent bookings',
        detail:
            'Recommendations appear after confirmed owner bookings land in this window.',
        priority: 'low',
      ),
    ],
  );

  final int confirmedCount;
  final int cancelledCount;
  final int occupancyPercent;
  final double revenue;
  final List<OptimizerHourBucket> hourly;
  final List<OptimizerVenueStat> venues;
  final List<OptimizerRecommendation> recommendations;
  final List<OptimizerDayPoint> daily;
  final OptimizerTrend trend;

  bool get isEmpty => confirmedCount == 0 && cancelledCount == 0;
}

/// Owner performance / recommendation engine.
///
/// Legacy Android used in-memory occupancy fixtures. This uses live owner
/// bookings so recommendations stay tied to actual demand.
class VenueOptimizerEngine {
  static VenueOptimizerReport build({
    required List<Booking> bookings,
    required DateTime now,
    Duration window = const Duration(days: 30),
    DateTime? start,
    DateTime? end,
    Set<String>? venueIds,
  }) {
    final rangeEnd = DateTime(
      (end ?? now).year,
      (end ?? now).month,
      (end ?? now).day,
    );
    final rawStart = start ?? now.subtract(window);
    final rangeStart = DateTime(rawStart.year, rawStart.month, rawStart.day);
    final current = _compute(
      bookings: bookings,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      venueIds: venueIds,
    );
    if (current.isEmpty) return VenueOptimizerReport.empty();

    final spanDays = rangeEnd.difference(rangeStart).inDays;
    final previousEnd = rangeStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: spanDays));
    final previous = _compute(
      bookings: bookings,
      rangeStart: previousStart,
      rangeEnd: previousEnd,
      venueIds: venueIds,
    );
    return VenueOptimizerReport(
      confirmedCount: current.confirmedCount,
      cancelledCount: current.cancelledCount,
      occupancyPercent: current.occupancyPercent,
      revenue: current.revenue,
      hourly: current.hourly,
      venues: current.venues,
      recommendations: current.recommendations,
      daily: current.daily,
      trend: OptimizerTrend(
        bookingDelta: current.confirmedCount - previous.confirmedCount,
        revenueDelta: current.revenue - previous.revenue,
        occupancyDelta: current.occupancyPercent - previous.occupancyPercent,
      ),
    );
  }

  static VenueOptimizerReport _compute({
    required List<Booking> bookings,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Set<String>? venueIds,
  }) {
    final inWindow = bookings
        .where((booking) {
          if (venueIds != null && !venueIds.contains(booking.venueId)) {
            return false;
          }
          final day = DateTime(
            booking.bookDate.year,
            booking.bookDate.month,
            booking.bookDate.day,
          );
          return !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
        })
        .toList(growable: false);

    final confirmed = inWindow
        .where(
          (booking) =>
              booking.status == BookingStatus.confirmed ||
              booking.status == BookingStatus.completed,
        )
        .toList(growable: false);
    final cancelled = inWindow
        .where(
          (booking) =>
              booking.status == BookingStatus.cancelled ||
              booking.status == BookingStatus.refunded,
        )
        .toList(growable: false);

    if (inWindow.isEmpty) return VenueOptimizerReport.empty();

    final hourCounts = <int, int>{};
    for (final booking in confirmed) {
      final hour = int.tryParse(booking.startTime.split(':').first) ?? 0;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }
    final peakCount = hourCounts.values.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );
    final hourly = List<OptimizerHourBucket>.generate(8, (index) {
      final hour = 6 + index * 2;
      final count = (hourCounts[hour] ?? 0) + (hourCounts[hour + 1] ?? 0);
      final share = confirmed.isEmpty
          ? 0
          : ((count / confirmed.length) * 100).round();
      return OptimizerHourBucket(
        hour: hour,
        label:
            '${hour.toString().padLeft(2, '0')}:00–${(hour + 2).toString().padLeft(2, '0')}:00',
        bookingCount: count,
        sharePercent: share,
        isPeak:
            peakCount > 0 && count >= (peakCount * 0.75).ceil() && count > 0,
      );
    });

    final byVenue = <String, OptimizerVenueStat>{};
    for (final booking in inWindow) {
      final current =
          byVenue[booking.venueId] ??
          OptimizerVenueStat(
            venueId: booking.venueId,
            venueName: booking.venueName.isEmpty
                ? booking.venueId
                : booking.venueName,
            confirmedCount: 0,
            cancelledCount: 0,
            revenue: 0,
          );
      final isConfirmed =
          booking.status == BookingStatus.confirmed ||
          booking.status == BookingStatus.completed;
      final isCancelled =
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.refunded;
      byVenue[booking.venueId] = OptimizerVenueStat(
        venueId: current.venueId,
        venueName: current.venueName,
        confirmedCount: current.confirmedCount + (isConfirmed ? 1 : 0),
        cancelledCount: current.cancelledCount + (isCancelled ? 1 : 0),
        revenue: current.revenue + (isConfirmed ? booking.totalAmount : 0),
      );
    }

    final occupancyDenom = confirmed.length + cancelled.length;
    final occupancy = occupancyDenom == 0
        ? 0
        : ((confirmed.length / occupancyDenom) * 100).round();
    final revenue = confirmed.fold<double>(
      0,
      (sum, row) => sum + row.totalAmount,
    );
    final recommendations = <OptimizerRecommendation>[];
    final peak = hourly.where((bucket) => bucket.isPeak).toList();
    final quiet = hourly
        .where((bucket) => bucket.bookingCount == 0 || bucket.sharePercent < 10)
        .toList();
    if (peak.isNotEmpty) {
      recommendations.add(
        OptimizerRecommendation(
          title: 'Peak demand ${peak.first.label}',
          detail:
              '${peak.first.sharePercent}% of confirmed bookings land in this window. Keep inventory open and consider a modest peak rate.',
          priority: 'high',
        ),
      );
    }
    if (quiet.isNotEmpty && confirmed.isNotEmpty) {
      recommendations.add(
        OptimizerRecommendation(
          title: 'Promote off-peak ${quiet.first.label}',
          detail:
              'Few bookings in this window. A limited off-peak offer can lift occupancy without changing the live price engine.',
        ),
      );
    }
    if (occupancyDenom > 0 && cancelled.length / occupancyDenom >= 0.2) {
      recommendations.add(
        const OptimizerRecommendation(
          title: 'Cancellations are high',
          detail:
              'More than 20% of recent bookings were cancelled or refunded. Pre-session reminders and a 24-hour follow-up help recover those slots.',
          priority: 'high',
        ),
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        const OptimizerRecommendation(
          title: 'Demand is balanced',
          detail:
              'No strong peak/off-peak split in this window. Keep current rates and watch weekly occupancy.',
          priority: 'low',
        ),
      );
    }

    final venues = byVenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final byDay = <DateTime, int>{};
    for (final booking in confirmed) {
      final day = DateTime(
        booking.bookDate.year,
        booking.bookDate.month,
        booking.bookDate.day,
      );
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    final daily =
        byDay.entries
            .map(
              (entry) => OptimizerDayPoint(
                day: entry.key,
                confirmedCount: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    return VenueOptimizerReport(
      confirmedCount: confirmed.length,
      cancelledCount: cancelled.length,
      occupancyPercent: occupancy,
      revenue: revenue,
      hourly: hourly,
      venues: venues,
      recommendations: recommendations,
      daily: daily,
    );
  }
}

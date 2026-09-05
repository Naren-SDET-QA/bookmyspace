import '../../booking/domain/booking.dart';

enum PeakHoursDayFilter { all, weekday, weekend }

class PeakHourBucket {
  const PeakHourBucket({
    required this.hour,
    required this.label,
    required this.bookingCount,
    required this.occupancyPercent,
    required this.isPeak,
  });

  final int hour;
  final String label;
  final int bookingCount;
  final double occupancyPercent;
  final bool isPeak;

  String get crowdStatus {
    if (occupancyPercent >= 75) return 'Peak crowd';
    if (occupancyPercent >= 45) return 'Moderate';
    return 'Quiet';
  }
}

class PeakHoursReport {
  const PeakHoursReport({
    required this.hourly,
    required this.confirmedCount,
    this.peakHour,
    this.quietHour,
  });

  factory PeakHoursReport.empty() =>
      const PeakHoursReport(hourly: [], confirmedCount: 0);

  final List<PeakHourBucket> hourly;
  final int confirmedCount;
  final PeakHourBucket? peakHour;
  final PeakHourBucket? quietHour;

  bool get isEmpty => confirmedCount == 0;
}

/// Hourly occupancy from live owner bookings (not fixture traffic).
class PeakHoursCalculator {
  static const peakShareThreshold = 30.0;

  static PeakHoursReport build({
    required List<Booking> bookings,
    required DateTime start,
    required DateTime end,
    PeakHoursDayFilter dayFilter = PeakHoursDayFilter.all,
    Set<String>? venueIds,
  }) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    final confirmed = <Booking>[];
    for (final booking in bookings) {
      if (venueIds != null && !venueIds.contains(booking.venueId)) continue;
      if (!_inRange(booking.bookDate, rangeStart, rangeEnd)) continue;
      if (!_matchesDay(booking.bookDate, dayFilter)) continue;
      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.completed) {
        continue;
      }
      confirmed.add(booking);
    }

    if (confirmed.isEmpty) return PeakHoursReport.empty();

    final counts = List<int>.filled(24, 0);
    for (final booking in confirmed) {
      final hour = _hourOf(booking.startTime);
      counts[hour] += 1;
    }
    final maxCount = counts.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );
    final hourly = <PeakHourBucket>[
      for (var hour = 0; hour < 24; hour++)
        PeakHourBucket(
          hour: hour,
          label: _label(hour),
          bookingCount: counts[hour],
          occupancyPercent: confirmed.isEmpty
              ? 0
              : (counts[hour] / confirmed.length) * 100,
          isPeak:
              counts[hour] > 0 &&
              (counts[hour] == maxCount ||
                  (counts[hour] / confirmed.length) * 100 >=
                      peakShareThreshold),
        ),
    ];

    PeakHourBucket? peak;
    for (final bucket in hourly) {
      if (bucket.isPeak) {
        peak = bucket;
        break;
      }
    }
    PeakHourBucket? quiet;
    for (final bucket in hourly) {
      if (bucket.hour < 8 || bucket.hour > 22) continue;
      if (quiet == null || bucket.bookingCount < quiet.bookingCount) {
        quiet = bucket;
      }
    }

    return PeakHoursReport(
      hourly: hourly,
      confirmedCount: confirmed.length,
      peakHour: peak,
      quietHour: quiet,
    );
  }

  static bool _inRange(DateTime date, DateTime start, DateTime end) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static bool _matchesDay(DateTime date, PeakHoursDayFilter filter) {
    if (filter == PeakHoursDayFilter.all) return true;
    final weekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    return filter == PeakHoursDayFilter.weekend ? weekend : !weekend;
  }

  static int _hourOf(String startTime) {
    final hour = int.tryParse(startTime.split(':').first) ?? 0;
    if (hour < 0) return 0;
    if (hour > 23) return 23;
    return hour;
  }

  static String _label(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:00 $period';
  }
}

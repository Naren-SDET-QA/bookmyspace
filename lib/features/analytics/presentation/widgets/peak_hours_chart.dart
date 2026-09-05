import 'package:flutter/material.dart';

import '../../domain/peak_hours_analytics.dart';

class PeakHoursChart extends StatelessWidget {
  const PeakHoursChart({
    super.key,
    required this.report,
    required this.dayFilter,
    required this.onFilterChanged,
  });

  final PeakHoursReport report;
  final PeakHoursDayFilter dayFilter;
  final ValueChanged<PeakHoursDayFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('peak_hours_chart_card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peak booking hours',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hourly occupancy from your venue bookings in this date range.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PeakHoursDayFilter>(
              segments: const [
                ButtonSegment(
                  value: PeakHoursDayFilter.all,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: PeakHoursDayFilter.weekday,
                  label: Text('Weekdays'),
                ),
                ButtonSegment(
                  value: PeakHoursDayFilter.weekend,
                  label: Text('Weekends'),
                ),
              ],
              selected: {dayFilter},
              onSelectionChanged: (value) => onFilterChanged(value.first),
            ),
            const SizedBox(height: 16),
            if (report.isEmpty)
              Text(
                'No hourly pattern yet',
                key: const Key('peak_hours_empty'),
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              if (report.peakHour != null)
                Text(
                  'Peak ${report.peakHour!.label} · ${report.peakHour!.occupancyPercent.round()}% of bookings',
                  key: const Key('peak_hours_peak_label'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (report.quietHour != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Quietest ${report.quietHour!.label} · ${report.quietHour!.bookingCount} bookings',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                key: const Key('peak_hours_line_canvas'),
                height: 140,
                child: CustomPaint(
                  painter: _HourlyBars(
                    report.hourly,
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary.withValues(alpha: 0.55),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              for (final bucket in report.hourly.where((item) => item.isPeak))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bucket.label,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      Text(
                        '${bucket.occupancyPercent.round()}% (${bucket.bookingCount})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HourlyBars extends CustomPainter {
  const _HourlyBars(this.hours, this.peakColor, this.baseColor);

  final List<PeakHourBucket> hours;
  final Color peakColor;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;
    final max = hours.fold<int>(
      0,
      (current, hour) =>
          hour.bookingCount > current ? hour.bookingCount : current,
    );
    final width = size.width / hours.length;
    for (var i = 0; i < hours.length; i++) {
      final hour = hours[i];
      final h = max == 0 ? 0.0 : hour.bookingCount / max * (size.height - 8);
      final paint = Paint()..color = hour.isPeak ? peakColor : baseColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * width + 1.5, size.height - h, width - 3, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyBars oldDelegate) =>
      oldDelegate.hours != hours;
}

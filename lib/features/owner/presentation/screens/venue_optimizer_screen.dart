import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../owner_bookings/presentation/owner_booking_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/venue_optimizer.dart';

class VenueOptimizerScreen extends ConsumerStatefulWidget {
  const VenueOptimizerScreen({super.key});

  @override
  ConsumerState<VenueOptimizerScreen> createState() =>
      _VenueOptimizerScreenState();
}

class _VenueOptimizerScreenState extends ConsumerState<VenueOptimizerScreen> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(ownerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Venue Optimizer')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(ownerBookingsProvider),
        ),
        data: (items) {
          final now = DateTime.now();
          final end = DateTime(now.year, now.month, now.day);
          final start = end.subtract(Duration(days: _days - 1));
          final report = VenueOptimizerEngine.build(
            bookings: items,
            now: now,
            start: start,
            end: end,
          );
          return ListView(
            key: const Key('venue_optimizer_dashboard'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Performance from live owner bookings.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _rangeChip(7, '7 days'),
                  _rangeChip(30, '30 days'),
                  _rangeChip(90, '90 days'),
                ],
              ),
              const SizedBox(height: 16),
              if (report.isEmpty)
                const EmptyState(
                  key: Key('optimizer_empty'),
                  icon: Icons.insights_outlined,
                  title: 'No optimizer data',
                  message:
                      'Confirmed bookings on your venues in this range will fill occupancy, trends and recommendations.',
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Occupancy',
                        value: '${report.occupancyPercent}%',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Confirmed',
                        value: '${report.confirmedCount}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: 'Revenue',
                        value: formatInr(report.revenue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TrendCard(trend: report.trend),
                if (report.venues.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Venue comparison',
                    key: const Key('optimizer_venue_compare'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...report.venues.map(
                    (venue) => ListTile(
                      title: Text(venue.venueName),
                      subtitle: Text(
                        '${venue.confirmedCount} confirmed · ${venue.occupancyPercent}% occupancy',
                      ),
                      trailing: Text(formatInr(venue.revenue)),
                    ),
                  ),
                ],
                if (report.daily.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Booking trend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    key: const Key('optimizer_trend_chart'),
                    height: 88,
                    child: CustomPaint(
                      painter: _TrendBars(
                        report.daily,
                        Theme.of(context).colorScheme.primary,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Hourly demand',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (report.hourly.every((bucket) => bucket.bookingCount == 0))
                  const EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'No hourly pattern yet',
                    message:
                        'Confirmed bookings in this window will fill the demand bars.',
                  )
                else
                  ...report.hourly.map(
                    (bucket) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              bucket.label,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (bucket.sharePercent.clamp(0, 100)) / 100,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${bucket.sharePercent}%'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Recommendations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...report.recommendations.map(
                  (item) => Card(
                    child: ListTile(
                      leading: Icon(
                        item.priority == 'high'
                            ? Icons.priority_high_rounded
                            : Icons.lightbulb_outline,
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.detail),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _rangeChip(int days, String label) {
    return ChoiceChip(
      key: Key('optimizer_range_$days'),
      label: Text(label),
      selected: _days == days,
      onSelected: (_) => setState(() => _days = days),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final OptimizerTrend trend;

  @override
  Widget build(BuildContext context) {
    String signed(num value, {bool money = false}) {
      final prefix = value > 0 ? '+' : '';
      if (money) return '$prefix${formatInr(value.toDouble())}';
      return '$prefix${value.round()}';
    }

    return Card(
      key: const Key('optimizer_trend'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'vs prior period',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Text('Bookings ${signed(trend.bookingDelta)}'),
            const SizedBox(width: 12),
            Text(signed(trend.revenueDelta, money: true)),
          ],
        ),
      ),
    );
  }
}

class _TrendBars extends CustomPainter {
  const _TrendBars(this.points, this.color);

  final List<OptimizerDayPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final max = points.fold<int>(
      0,
      (current, point) =>
          point.confirmedCount > current ? point.confirmedCount : current,
    );
    final width = size.width / points.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final h = max == 0
          ? 0.0
          : points[i].confirmedCount / max * (size.height - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * width + 2, size.height - h, width - 4, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBars oldDelegate) =>
      oldDelegate.points != points;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

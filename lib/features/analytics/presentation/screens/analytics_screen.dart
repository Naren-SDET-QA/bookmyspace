import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/modular/feature_id.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../owner_bookings/presentation/owner_booking_providers.dart';
import '../../domain/analytics_display_config.dart';
import '../../domain/peak_hours_analytics.dart';
import '../../domain/revenue_analytics.dart';
import '../analytics_providers.dart';
import '../widgets/peak_hours_chart.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  late DateTimeRange _range;
  var _dayFilter = PeakHoursDayFilter.all;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = AnalyticsDisplayConfig.fromFeature(
      ref.watch(featureRegistryProvider).configOf(FeatureId.analytics),
    );
    final query = ref.watch(
      revenueAnalyticsProvider((start: _range.start, end: _range.end)),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue & Booking Analytics'),
        actions: [
          if (query.hasValue)
            IconButton(
              tooltip: 'Share report',
              icon: const Icon(Icons.share_rounded),
              onPressed: () =>
                  _shareReport(context, query.value!, _range),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              if (display.dateRanges.contains('today'))
                _button('Today', () => _setDays(0)),
              if (display.dateRanges.contains('last_7_days'))
                _button('Last 7 days', () => _setDays(6)),
              if (display.dateRanges.contains('this_month'))
                _button('This month', () {
                  final n = DateTime.now();
                  setState(
                    () => _range = DateTimeRange(
                      start: DateTime(n.year, n.month),
                      end: DateTime(n.year, n.month + 1, 0),
                    ),
                  );
                }),
              if (display.dateRanges.contains('custom'))
                _button('Custom', _customRange),
            ],
          ),
          const SizedBox(height: 16),
          query.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(
                revenueAnalyticsProvider((
                  start: _range.start,
                  end: _range.end,
                )),
              ),
            ),
            data: (data) => data.isEmpty
                ? const EmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'No analytics data',
                    message:
                        'There is no booking or payment activity in this range.',
                  )
                : _Dashboard(data: data, display: display),
          ),
          if (display.showCharts) _peakHoursSection(),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) =>
      OutlinedButton(onPressed: onTap, child: Text(label));
  void _setDays(int days) {
    final e = DateTime.now();
    final day = DateTime(e.year, e.month, e.day);
    setState(
      () => _range = DateTimeRange(
        start: day.subtract(Duration(days: days)),
        end: day,
      ),
    );
  }

  Future<void> _customRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  /// Plain-text report summary for sharing -- mirrors the Android reference
  /// app's daily/weekly report share action, built from the same
  /// server-computed [RevenueAnalytics] already on screen (no separate
  /// report data source).
  static String _reportSummaryText(RevenueAnalytics data, DateTimeRange range) {
    final fmt = DateFormat.yMMMd();
    String inr(double v) => '₹${v.toStringAsFixed(2)}';
    return 'BookMySpace report: ${fmt.format(range.start)} - ${fmt.format(range.end)}\n'
        'Total revenue: ${inr(data.totalRevenue)}\n'
        'Net revenue: ${inr(data.netRevenue)}\n'
        'Successful bookings: ${data.successfulBookings}\n'
        'Cancelled bookings: ${data.cancelledBookings}\n'
        'Refund amount: ${inr(data.refundAmount)}\n'
        'Average booking value: ${inr(data.averageBookingValue)}';
  }

  Future<void> _shareReport(
    BuildContext context,
    RevenueAnalytics data,
    DateTimeRange range,
  ) async {
    final summary = _reportSummaryText(data, range);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy summary'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: summary));
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded),
              title: const Text('Share via WhatsApp'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final uri = Uri.parse(
                  'https://wa.me/?text=${Uri.encodeComponent(summary)}',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _peakHoursSection() {
    final bookings = ref.watch(ownerBookingsProvider);
    return bookings.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(ownerBookingsProvider),
        ),
      ),
      data: (items) {
        final report = PeakHoursCalculator.build(
          bookings: items,
          start: _range.start,
          end: _range.end,
          dayFilter: _dayFilter,
        );
        return PeakHoursChart(
          report: report,
          dayFilter: _dayFilter,
          onFilterChanged: (value) => setState(() => _dayFilter = value),
        );
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.display});
  final RevenueAnalytics data;
  final AnalyticsDisplayConfig display;
  @override
  Widget build(BuildContext context) {
    final kpis = <String, Widget>{
      'total_revenue': _Kpi('Total Revenue', data.totalRevenue),
      'successful_bookings': _Kpi(
        'Successful Bookings',
        data.successfulBookings,
      ),
      'cancelled_bookings': _Kpi('Cancelled Bookings', data.cancelledBookings),
      'refund_amount': _Kpi('Refund Amount', data.refundAmount),
      'net_revenue': _Kpi('Net Revenue', data.netRevenue),
      'average_booking': _Kpi('Average Booking', data.averageBookingValue),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (display.showKpis)
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            children: [
              for (final key in display.kpiOrder)
                if (kpis[key] != null) kpis[key]!,
            ],
          ),
        if (display.showCharts) ...[
          if (display.showDaily) _Chart('Daily Revenue', data.dailyRevenue),
          if (display.showWeekly) _Chart('Weekly Revenue', data.weeklyRevenue),
          if (display.showMonthly)
            _Chart('Monthly Revenue', data.monthlyRevenue),
          _Chart('Booking Count', data.bookingTrend, count: true),
          if (display.showCategoryBreakdown)
            _Breakdown('Revenue by Category', data.categoryRevenue),
          if (display.showListingBreakdown)
            _Breakdown('Revenue by Listing', data.venueRevenue),
        ],
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final Object value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value is double
                ? '₹${(value as double).toStringAsFixed(2)}'
                : '$value',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  );
}

class _Chart extends StatelessWidget {
  const _Chart(this.title, this.points, {this.count = false});
  final String title;
  final List<AnalyticsPoint> points;
  final bool count;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _Bars(
                points,
                count,
                Theme.of(context).colorScheme.primary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Bars extends CustomPainter {
  const _Bars(this.points, this.count, this.color);
  final List<AnalyticsPoint> points;
  final bool count;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points
        .map((p) => count ? p.count.toDouble() : p.value)
        .toList();
    final max = values.fold<double>(
      0,
      (current, value) => current > value ? current : value,
    );
    final width = size.width / values.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = max == 0 ? 0.0 : values[i] / max * (size.height - 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * width + 3, size.height - h, width - 6, h),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Bars oldDelegate) =>
      oldDelegate.points != points;
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.title, this.items);
  final String title;
  final List<AnalyticsBreakdown> items;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: ExpansionTile(
      title: Text(title),
      children: [
        for (final item in items.take(20))
          ListTile(
            title: Text(item.label),
            subtitle: Text('${item.count} bookings'),
            trailing: Text('₹${item.value.toStringAsFixed(2)}'),
          ),
      ],
    ),
  );
}

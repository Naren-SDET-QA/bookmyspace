import '../../../core/modular/feature_config.dart';

/// Display knobs for the existing Revenue Analytics screen.
/// Stored on FeatureId.analytics FeatureConfig.config — not a second analytics store.
class AnalyticsDisplayConfig {
  const AnalyticsDisplayConfig({
    this.showKpis = true,
    this.showCharts = true,
    this.showDaily = true,
    this.showWeekly = true,
    this.showMonthly = true,
    this.showCategoryBreakdown = true,
    this.showListingBreakdown = true,
    this.kpiOrder = const [
      'total_revenue',
      'successful_bookings',
      'cancelled_bookings',
      'refund_amount',
      'net_revenue',
      'average_booking',
    ],
    this.dateRanges = const ['today', 'last_7_days', 'this_month', 'custom'],
  });

  final bool showKpis;
  final bool showCharts;
  final bool showDaily;
  final bool showWeekly;
  final bool showMonthly;
  final bool showCategoryBreakdown;
  final bool showListingBreakdown;
  final List<String> kpiOrder;
  final List<String> dateRanges;

  factory AnalyticsDisplayConfig.fromFeature(FeatureConfig config) {
    List<String> strings(dynamic raw, List<String> fallback) {
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((item) => item.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return fallback;
    }

    bool flag(String key, bool fallback) {
      final value = config.config[key];
      if (value is bool) return value;
      return fallback;
    }

    const defaults = AnalyticsDisplayConfig();
    final showCharts = flag('show_charts', defaults.showCharts);
    return AnalyticsDisplayConfig(
      showKpis: flag('show_kpis', defaults.showKpis),
      showCharts: showCharts,
      showDaily: flag('show_daily', showCharts),
      showWeekly: flag('show_weekly', showCharts),
      showMonthly: flag('show_monthly', showCharts),
      showCategoryBreakdown: flag('show_category_breakdown', showCharts),
      showListingBreakdown: flag('show_listing_breakdown', showCharts),
      kpiOrder: strings(config.config['kpi_order'], defaults.kpiOrder),
      dateRanges: strings(config.config['date_ranges'], defaults.dateRanges),
    );
  }
}

import 'revenue_analytics.dart';

abstract interface class AnalyticsRepository {
  Future<RevenueAnalytics> revenue({
    required DateTime start,
    required DateTime end,
    required bool admin,
  });
}

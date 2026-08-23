import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/analytics_repository.dart';
import '../domain/revenue_analytics.dart';

class SupabaseRevenueAnalyticsRepository implements AnalyticsRepository {
  const SupabaseRevenueAnalyticsRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<RevenueAnalytics> revenue({
    required DateTime start,
    required DateTime end,
    required bool admin,
  }) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'get_revenue_analytics',
      params: {
        'p_start_date': _date(start),
        'p_end_date': _date(end),
        'p_scope': admin ? 'admin' : 'owner',
      },
    );
    return RevenueAnalytics.fromJson(result);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

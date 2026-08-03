import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' as app_errors;
import '../domain/analytics_event.dart';
import '../domain/analytics_event_repository.dart';

class SupabaseAnalyticsRepository implements AnalyticsEventRepository {
  SupabaseAnalyticsRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<void> track(AnalyticsEvent event) async {
    try {
      await _client.from('analytics_events').insert({
        'user_id': _userId,
        'event_type': event.eventType.dbValue,
        'properties': event.properties,
      });
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }

  @override
  Future<List<AnalyticsEvent>> recentEvents({int limit = 50}) async {
    try {
      final rows = await _client
          .from('analytics_events')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map((r) => AnalyticsEvent.fromJson(r)).toList();
    } catch (e) {
      throw app_errors.mapError(e);
    }
  }
}
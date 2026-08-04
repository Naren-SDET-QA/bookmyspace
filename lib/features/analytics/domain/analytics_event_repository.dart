import '../domain/analytics_event.dart';

abstract interface class AnalyticsEventRepository {
  Future<void> track(AnalyticsEvent event);
  Future<List<AnalyticsEvent>> recentEvents({int limit});
}

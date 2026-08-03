import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/analytics_event.dart';
import '../domain/analytics_event_repository.dart';
import '../infrastructure/supabase_analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsEventRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseAnalyticsRepository(client);
});

final recentAnalyticsEventsProvider = FutureProvider<List<AnalyticsEvent>>((ref) {
  return ref.watch(analyticsRepositoryProvider).recentEvents(limit: 50);
});
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/booking/domain/booking_reminder_scheduler.dart';
import '../../features/search/domain/recent_search.dart';
import '../../features/support/domain/contextual_help.dart';
import 'offline_cache.dart';
import 'offline_store.dart';

final offlineStoreProvider = Provider<OfflineStore>((ref) {
  return MemoryOfflineStore();
});

final servingCachedDataProvider = StateProvider<bool>((ref) => false);

final offlineCacheProvider = Provider<OfflineCache>((ref) {
  return OfflineCache(
    ref.watch(offlineStoreProvider),
    onServe: (fromCache) {
      ref.read(servingCachedDataProvider.notifier).state = fromCache;
    },
  );
});

final localReminderGatewayProvider = Provider<LocalReminderGateway>((ref) {
  return const NoopLocalReminderGateway();
});

final bookingReminderSchedulerProvider = Provider<BookingReminderScheduler>((
  ref,
) {
  return BookingReminderScheduler(
    gateway: ref.watch(localReminderGatewayProvider),
  );
});

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<RecentSearch>>(
      RecentSearchesNotifier.new,
    );

class RecentSearchesNotifier extends AsyncNotifier<List<RecentSearch>> {
  RecentSearchStore get _store => RecentSearchStore(ref.read(offlineStoreProvider));

  @override
  Future<List<RecentSearch>> build() => _store.load();

  Future<void> add(String query) async {
    state = AsyncData(await _store.add(query));
  }

  Future<void> remove(String query) async {
    state = AsyncData(await _store.remove(query));
  }

  Future<void> clear() async {
    state = AsyncData(await _store.clear());
  }
}

final contextualHelpStoreProvider = Provider<ContextualHelpStore>((ref) {
  return ContextualHelpStore(ref.watch(offlineStoreProvider));
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/rewards_repository.dart';
import '../infrastructure/supabase_rewards_repository.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) => SupabaseRewardsRepository(ref.watch(supabaseProvider)),
);
final referralSummaryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(rewardsRepositoryProvider).referralSummary(),
);
final walletEntriesProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(rewardsRepositoryProvider).walletEntries(),
);

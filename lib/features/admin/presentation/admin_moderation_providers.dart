import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/listing_moderation.dart';
import '../domain/listing_moderation_repository.dart';
import '../infrastructure/supabase_listing_moderation_repository.dart';

final listingModerationRepositoryProvider =
    Provider<SupabaseListingModerationRepository>((ref) {
      return SupabaseListingModerationRepository(ref.watch(supabaseProvider));
    });

final listingLifecycleRepositoryProvider = Provider<ListingLifecycleRepository>(
  (ref) => ref.watch(listingModerationRepositoryProvider),
);

final adminListingsProvider =
    FutureProvider.family<List<ModeratedListing>, String?>((ref, status) {
      return ref
          .watch(listingModerationRepositoryProvider)
          .listings(status: status);
    });

final adminBookingsOversightProvider = FutureProvider<List<OversightRow>>((
  ref,
) {
  return ref.watch(listingModerationRepositoryProvider).bookings();
});

final adminPaymentsOversightProvider = FutureProvider<List<OversightRow>>((
  ref,
) {
  return ref.watch(listingModerationRepositoryProvider).payments();
});

final adminRefundsOversightProvider = FutureProvider<List<OversightRow>>((ref) {
  return ref.watch(listingModerationRepositoryProvider).refunds();
});

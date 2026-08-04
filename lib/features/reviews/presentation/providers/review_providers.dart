import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../domain/review.dart';
import '../../infrastructure/supabase_review_repository.dart';

/// Review repository instance.
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseReviewRepository(client);
});

/// Reviews for a specific venue.
final venueReviewsProvider = FutureProvider.autoDispose
    .family<List<Review>, String>((ref, venueId) {
      return ref.watch(reviewRepositoryProvider).venueReviews(venueId);
    });

/// Current user's review for a venue.
final myReviewProvider = FutureProvider.autoDispose.family<Review?, String>((
  ref,
  venueId,
) {
  return ref.watch(reviewRepositoryProvider).myReviewForVenue(venueId);
});

/// Submit a new review.
final submitReviewProvider = FutureProvider.autoDispose
    .family<
      Review,
      ({String venueId, int rating, String? title, String? body})
    >((ref, params) async {
      final repo = ref.watch(reviewRepositoryProvider);
      final review = await repo.submitReview(
        venueId: params.venueId,
        rating: params.rating,
        title: params.title,
        body: params.body,
      );
      ref.invalidate(venueReviewsProvider(params.venueId));
      ref.invalidate(myReviewProvider(params.venueId));
      return review;
    });

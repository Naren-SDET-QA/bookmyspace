import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/review.dart';

/// Supabase-backed [ReviewRepository].
class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Review>> venueReviews(String venueId) async {
    try {
      final rows = await _client
          .from('reviews')
          .select('*')
          .eq('venue_id', venueId)
          .order('created_at', ascending: false);
      return rows.map(Review.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Review?> myReviewForVenue(String venueId) async {
    if (_userId == null) return null;
    try {
      final rows = await _client
          .from('reviews')
          .select('*')
          .eq('venue_id', venueId)
          .eq('user_id', _userId!)
          .limit(1);
      if (rows.isEmpty) return null;
      return Review.fromJson(rows.first);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Review> submitReview({
    required String venueId,
    required int rating,
    String? title,
    String? body,
    String? bookingId,
  }) async {
    try {
      final rows = await _client
          .from('reviews')
          .insert({
            'venue_id': venueId,
            'user_id': _userId!,
            'rating': rating,
            'title': title,
            'body': body,
            'booking_id': bookingId,
          })
          .select()
          .limit(1);
      return Review.fromJson(rows.first);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? title,
    String? body,
  }) async {
    try {
      final update = <String, dynamic>{};
      if (rating != null) update['rating'] = rating;
      if (title != null) update['title'] = title;
      if (body != null) update['body'] = body;

      final rows = await _client
          .from('reviews')
          .update(update)
          .eq('id', reviewId)
          .select()
          .limit(1);
      return Review.fromJson(rows.first);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      await _client.from('reviews').delete().eq('id', reviewId);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<double> averageRating(String venueId) async {
    try {
      final rows = await _client
          .from('reviews')
          .select('rating')
          .eq('venue_id', venueId);
      if (rows.isEmpty) return 0;
      final total = rows.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
      return total / rows.length;
    } catch (e) {
      throw mapError(e);
    }
  }
}

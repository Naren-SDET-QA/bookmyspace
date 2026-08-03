/// A user review for a venue.
class Review {
  const Review({
    required this.id,
    required this.venueId,
    required this.userId,
    required this.rating,
    this.bookingId,
    this.title,
    this.body,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.userName,
  });

  final String id;
  final String venueId;
  final String userId;
  final int rating;
  final String? bookingId;
  final String? title;
  final String? body;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? userName;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String? ?? '',
    venueId: json['venue_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    rating: json['rating'] as int? ?? 0,
    bookingId: json['booking_id'] as String?,
    title: json['title'] as String?,
    body: json['body'] as String?,
    isVerified: json['is_verified'] as bool? ?? false,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
    userName: json['user_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'venue_id': venueId,
    'user_id': userId,
    'rating': rating,
    'booking_id': bookingId,
    'title': title,
    'body': body,
  };
}

/// Contract for review repository.
abstract interface class ReviewRepository {
  /// Get all reviews for a venue.
  Future<List<Review>> venueReviews(String venueId);

  /// Get the current user's review for a venue (if any).
  Future<Review?> myReviewForVenue(String venueId);

  /// Submit a new review.
  Future<Review> submitReview({
    required String venueId,
    required int rating,
    String? title,
    String? body,
    String? bookingId,
  });

  /// Update an existing review.
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? title,
    String? body,
  });

  /// Delete a review.
  Future<void> deleteReview(String reviewId);

  /// Get average rating for a venue.
  Future<double> averageRating(String venueId);
}

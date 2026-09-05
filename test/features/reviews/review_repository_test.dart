import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/features/reviews/domain/review.dart';
import 'package:bookmyspace/features/reviews/domain/review_validation.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({this.currentUserId});

  String? currentUserId;
  final _reviews = <Review>[];

  @override
  Future<List<Review>> venueReviews(String venueId) async =>
      _reviews.where((review) => review.venueId == venueId).toList();

  @override
  Future<Review?> myReviewForVenue(String venueId) async {
    if (currentUserId == null) return null;
    for (final review in _reviews) {
      if (review.venueId == venueId && review.userId == currentUserId) {
        return review;
      }
    }
    return null;
  }

  @override
  Future<Review> submitReview({
    required String venueId,
    required int rating,
    String? title,
    String? body,
    String? bookingId,
    List<String> tags = const [],
  }) async {
    ReviewValidation.ensureSignedIn(currentUserId);
    ReviewValidation.validate(rating: rating, title: title, body: body);
    if (await myReviewForVenue(venueId) != null) {
      throw const BusinessException('Already reviewed', code: 'duplicate');
    }
    final review = Review(
      id: 'r${_reviews.length + 1}',
      venueId: venueId,
      userId: currentUserId!,
      rating: rating,
      title: title,
      body: body,
      bookingId: bookingId,
      tags: tags,
    );
    _reviews.add(review);
    return review;
  }

  @override
  Future<Review> updateReview({
    required String reviewId,
    int? rating,
    String? title,
    String? body,
  }) async {
    ReviewValidation.ensureSignedIn(currentUserId);
    ReviewValidation.validate(rating: rating, title: title, body: body);
    final index = _reviews.indexWhere((review) => review.id == reviewId);
    if (index < 0) throw const NotFoundException('Review not found');
    ReviewValidation.ensureOwner(
      userId: currentUserId,
      reviewUserId: _reviews[index].userId,
    );
    final current = _reviews[index];
    final updated = Review(
      id: current.id,
      venueId: current.venueId,
      userId: current.userId,
      rating: rating ?? current.rating,
      title: title ?? current.title,
      body: body ?? current.body,
      bookingId: current.bookingId,
    );
    _reviews[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    ReviewValidation.ensureSignedIn(currentUserId);
    Review? review;
    for (final item in _reviews) {
      if (item.id == reviewId) review = item;
    }
    if (review == null) throw const NotFoundException('Review not found');
    ReviewValidation.ensureOwner(
      userId: currentUserId,
      reviewUserId: review.userId,
    );
    _reviews.removeWhere((item) => item.id == reviewId);
  }

  @override
  Future<double> averageRating(String venueId) async {
    final items = await venueReviews(venueId);
    if (items.isEmpty) return 0;
    return items.fold<int>(0, (sum, item) => sum + item.rating) / items.length;
  }
}

void main() {
  test('rejects unsigned create and out-of-range ratings', () async {
    final repo = InMemoryReviewRepository();
    expect(
      () => repo.submitReview(venueId: 'v1', rating: 5),
      throwsA(isA<AuthException>()),
    );
    repo.currentUserId = 'u1';
    expect(
      () => repo.submitReview(venueId: 'v1', rating: 0),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => repo.submitReview(venueId: 'v1', rating: 6),
      throwsA(isA<BusinessException>()),
    );
  });

  test('create, read, update, delete own review', () async {
    final repo = InMemoryReviewRepository(currentUserId: 'u1');
    final created = await repo.submitReview(
      venueId: 'v1',
      rating: 5,
      title: 'Great',
      body: 'Loved it',
    );
    expect(created.id, isNotEmpty);
    expect((await repo.venueReviews('v1')).single.rating, 5);
    expect((await repo.myReviewForVenue('v1'))?.title, 'Great');
    expect(await repo.averageRating('v1'), 5);

    final updated = await repo.updateReview(
      reviewId: created.id,
      rating: 4,
      title: 'Good',
    );
    expect(updated.rating, 4);
    expect(updated.title, 'Good');

    await repo.deleteReview(created.id);
    expect(await repo.venueReviews('v1'), isEmpty);
  });

  test('submitted tags survive repository persistence and readback', () async {
    final repo = InMemoryReviewRepository(currentUserId: 'u1');
    final created = await repo.submitReview(
      venueId: 'v1',
      rating: 5,
      tags: const ['Clean Courts', 'Helpful Staff'],
    );
    final read = (await repo.venueReviews('v1')).single;
    expect(created.tags, ['Clean Courts', 'Helpful Staff']);
    expect(read.tags, ['Clean Courts', 'Helpful Staff']);
  });

  test('authorization blocks update and delete by another user', () async {
    final repo = InMemoryReviewRepository(currentUserId: 'owner');
    final created = await repo.submitReview(venueId: 'v1', rating: 5);
    repo.currentUserId = 'other';
    expect(
      () => repo.updateReview(reviewId: created.id, rating: 1),
      throwsA(isA<AuthException>()),
    );
    expect(() => repo.deleteReview(created.id), throwsA(isA<AuthException>()));
  });

  test('validation rejects oversized title and body', () {
    expect(
      () => ReviewValidation.validate(title: 'x' * 121),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => ReviewValidation.validate(body: 'x' * 2001),
      throwsA(isA<BusinessException>()),
    );
  });

  test('empty venue reviews have a zero average', () async {
    final repo = InMemoryReviewRepository();
    expect(await repo.venueReviews('empty'), isEmpty);
    expect(await repo.averageRating('empty'), 0);
  });

  test('review JSON preserves venue display content and rating', () {
    final review = Review.fromJson({
      'id': 'r1',
      'venue_id': 'v1',
      'user_id': 'u1',
      'rating': 4,
      'title': 'Great hall',
      'body': 'Clean and spacious',
      'is_verified': true,
    });
    expect(review.title, 'Great hall');
    expect(review.body, 'Clean and spacious');
    expect(review.rating, 4);
    expect(review.isVerified, isTrue);
  });
}

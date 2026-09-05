import 'package:bookmyspace/features/reviews/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'star filter matches Android review chips and preserves source order',
    () {
      const reviews = [
        Review(id: '1', venueId: 'v', userId: 'u1', rating: 5),
        Review(id: '2', venueId: 'v', userId: 'u2', rating: 3),
        Review(id: '3', venueId: 'v', userId: 'u3', rating: 5),
      ];

      expect(Review.filterByStar(reviews, 5).map((r) => r.id), ['1', '3']);
      expect(Review.filterByStar(reviews, null), reviews);
    },
  );

  test('review parses Android metadata fields', () {
    final review = Review.fromJson({
      'id': 'r',
      'venue_id': 'v',
      'user_id': 'u',
      'rating': 5,
      'user_name': 'Asha',
      'avatar_url': 'https://example.com/a.png',
      'tags': 'Clean, Spacious',
      'is_verified': true,
    });
    expect(review.userName, 'Asha');
    expect(review.avatarUrl, contains('example.com'));
    expect(review.tags, ['Clean', 'Spacious']);
    expect(review.isVerified, isTrue);
  });
}

import '../../../core/errors/app_exceptions.dart';

class ReviewValidation {
  static const minRating = 1;
  static const maxRating = 5;
  static const maxTitleLength = 120;
  static const maxBodyLength = 2000;

  static void ensureSignedIn(String? userId) {
    if (userId == null || userId.isEmpty) {
      throw const AuthException('You must be signed in to review.');
    }
  }

  static void ensureOwner({
    required String? userId,
    required String reviewUserId,
  }) {
    ensureSignedIn(userId);
    if (userId != reviewUserId) {
      throw const AuthException('You can only change your own review.');
    }
  }

  static void validate({int? rating, String? title, String? body}) {
    if (rating != null && (rating < minRating || rating > maxRating)) {
      throw const BusinessException(
        'Rating must be between 1 and 5.',
        code: 'invalid_rating',
      );
    }
    if (title != null && title.length > maxTitleLength) {
      throw const BusinessException(
        'Review title is too long.',
        code: 'invalid_title',
      );
    }
    if (body != null && body.length > maxBodyLength) {
      throw const BusinessException(
        'Review is too long.',
        code: 'invalid_body',
      );
    }
  }
}

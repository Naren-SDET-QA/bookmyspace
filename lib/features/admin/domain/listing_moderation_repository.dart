import 'listing_moderation.dart';

abstract interface class ListingModerationRepository {
  Future<List<ModeratedListing>> listings({String? status});

  Future<ModeratedListing> moderate({
    required String venueId,
    required String action,
    String? reason,
  });

  Future<List<OversightRow>> bookings({int limit = 50});

  Future<List<OversightRow>> payments({int limit = 50});

  Future<List<OversightRow>> refunds({int limit = 50});
}

abstract interface class ListingLifecycleRepository {
  Future<ModeratedListing> submitForReview(String venueId);
}

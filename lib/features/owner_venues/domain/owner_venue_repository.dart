import '../../venues/domain/venue.dart';

/// Contract for owner venue management repository.
abstract interface class OwnerVenueRepository {
  /// Get all venues belonging to the current owner.
  Future<List<Venue>> myVenues();

  /// Create a new venue.
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
  });

  /// Update an existing venue.
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
  });

  /// Soft-delete a venue.
  Future<void> deleteVenue(String venueId);
}

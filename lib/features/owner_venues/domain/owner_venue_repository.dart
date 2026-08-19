import '../../venues/domain/venue.dart';
import 'owner_listing_draft.dart';

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

  /// Create or update a listing, including photos and facilities.
  Future<Venue> saveListing({
    String? venueId,
    required OwnerListingDraft draft,
  });

  /// Publish or unpublish via existing `is_active`.
  Future<Venue> setPublished(String venueId, bool published);

  /// Replace gallery rows on `venue_images` (owner RLS write).
  Future<void> replaceImages(String venueId, List<String> imageUrls);

  /// Replace amenity rows on `venue_facilities` (owner RLS write).
  Future<void> replaceFacilities(String venueId, List<String> facilities);

  /// Upload a photo to the `venue-images` Storage bucket and return its public URL.
  Future<String> uploadPhoto({
    required String venueId,
    required List<int> bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  });
}


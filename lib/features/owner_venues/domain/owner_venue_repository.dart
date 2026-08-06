import '../../venues/domain/venue.dart';

/// A venue with its gallery and facilities, as returned by the owner detail
/// endpoint.
class OwnerVenueDetail {
  const OwnerVenueDetail({
    required this.venue,
    this.images = const [],
    this.facilities = const [],
  });

  final Venue venue;
  final List<VenueImage> images;
  final List<VenueFacility> facilities;

  factory OwnerVenueDetail.fromJson(Map<String, dynamic> json) {
    final venueRaw = json['venue'];
    // The detail RPC returns the venue row directly with `venue_categories`
    // nested as a sibling; tolerate a previously-deployed variant that wrapped
    // the row as {venue: {...}, venue_categories: {...}}.
    final Map<String, dynamic> venueMap;
    if (venueRaw is Map<String, dynamic> && venueRaw['venue'] is Map) {
      venueMap = {
        ...(venueRaw['venue'] as Map).cast<String, dynamic>(),
        if (venueRaw['venue_categories'] != null)
          'venue_categories': venueRaw['venue_categories'],
      };
    } else if (venueRaw is Map<String, dynamic>) {
      venueMap = venueRaw;
    } else {
      venueMap = const {};
    }
    final imagesRaw = json['images'] ?? const <dynamic>[];
    final facilitiesRaw = json['facilities'] ?? const <dynamic>[];
    return OwnerVenueDetail(
      venue: Venue.fromJson(venueMap),
      images: imagesRaw is List
          ? imagesRaw
                .whereType<Map<String, dynamic>>()
                .map(VenueImage.fromJson)
                .toList()
          : const [],
      facilities: facilitiesRaw is List
          ? facilitiesRaw
                .whereType<Map<String, dynamic>>()
                .map(VenueFacility.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Contract for owner venue management repository.
abstract interface class OwnerVenueRepository {
  /// Get all venues belonging to the current owner.
  Future<List<Venue>> myVenues();

  /// Full detail (venue + gallery + facilities) for the edit screen.
  Future<OwnerVenueDetail> venueDetail(String venueId);

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
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? phone,
    String? website,
    List<String>? amenities,
    List<String>? imageUrls,
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
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? phone,
    String? website,
    List<String>? amenities,
    List<String>? imageUrls,
  });

  /// Soft-delete a venue.
  Future<void> deleteVenue(String venueId);
}

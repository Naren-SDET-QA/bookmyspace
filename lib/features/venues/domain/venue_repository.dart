import 'venue.dart';

/// Venue lookup contract.
///
/// Implementations are swappable (Supabase, mock, etc.) without touching
/// presentation code.
abstract interface class VenueRepository {
  /// Seed list of venue categories.
  Future<List<VenueCategory>> categories();

  /// Featured / popular venues for the home screen.
  Future<List<Venue>> popularVenues({int limit = 10});

  /// Venues ordered by distance from [latitude]/[longitude].
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  });

  /// Full-text + filter search over active venues.
  Future<List<Venue>> search(VenueSearchQuery query);

  /// Rich venue detail including images, facilities and hours.
  Future<Venue> venueById(String id);

  /// Ids of venues favourited by the signed-in user.
  Future<List<String>> favoriteIds();

  /// Venues favourited by the signed-in user (hydrated).
  Future<List<Venue>> favorites();

  /// Adds/removes a venue from the user's favourites.
  Future<void> addFavorite(String venueId);
  Future<void> removeFavorite(String venueId);
}

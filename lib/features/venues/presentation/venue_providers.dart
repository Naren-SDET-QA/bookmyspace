import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../location/presentation/location_providers.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';

/// Venue repository instance.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseVenueRepository(client);
});

/// Seed venue categories for chips and search filters.
final venueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories();
});

/// Location-aware venues shown on the home screen.
final popularVenuesProvider = FutureProvider<List<Venue>>((ref) {
  final area = ref.watch(searchAreaProvider);
  return ref
      .watch(venueRepositoryProvider)
      .nearbyVenues(
        latitude: area.latitude,
        longitude: area.longitude,
        maxDistanceKm: area.radiusKm,
        limit: 10,
      );
});

/// Venues near the user's location (or a sensible default city centre).
final nearbyVenuesProvider = FutureProvider.autoDispose<List<Venue>>((
  ref,
) async {
  final area = ref.watch(searchAreaProvider);
  return ref
      .watch(venueRepositoryProvider)
      .nearbyVenues(
        latitude: area.latitude,
        longitude: area.longitude,
        maxDistanceKm: area.radiusKm,
        limit: 10,
      );
});

/// Holds the current search query; drives the search results provider.
final searchQueryProvider = StateProvider<VenueSearchQuery>((ref) {
  return const VenueSearchQuery();
});

/// Search results reacting to the current query.
final searchResultsProvider = FutureProvider<List<Venue>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return ref.watch(venueRepositoryProvider).search(query);
});

/// Ids of venues favourited by the signed-in user.
final favoriteIdsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(venueRepositoryProvider).favoriteIds();
});

/// Hydrated favourite venues.
final favoritesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).favorites();
});

/// A single venue's full details.
final venueDetailsProvider = FutureProvider.autoDispose.family<Venue, String>((
  ref,
  id,
) {
  return ref.watch(venueRepositoryProvider).venueById(id);
});

/// Toggles a venue in the user's favourites and invalidates the caches.
final toggleFavoriteProvider = FutureProvider.family<void, String>((
  ref,
  venueId,
) async {
  final repo = ref.watch(venueRepositoryProvider);
  final ids = await repo.favoriteIds();
  if (ids.contains(venueId)) {
    await repo.removeFavorite(venueId);
  } else {
    await repo.addFavorite(venueId);
  }
  ref.invalidate(favoriteIdsProvider);
  ref.invalidate(favoritesProvider);
});

/// Whether the given venue id is favourited (null while unknown).
final isFavoriteProvider = FutureProvider.autoDispose.family<bool?, String>((
  ref,
  venueId,
) async {
  final ids = await ref.watch(favoriteIdsProvider.future);
  return ids.contains(venueId);
});

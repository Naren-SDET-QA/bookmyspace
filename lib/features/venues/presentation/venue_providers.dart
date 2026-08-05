import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../infrastructure/demo_venue_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';

/// City centre used for nearby venue queries and the home location chip.
class SearchArea {
  const SearchArea({
    required this.cityLabel,
    required this.latitude,
    required this.longitude,
  });

  final String cityLabel;
  final double latitude;
  final double longitude;
}

/// Supported cities for the home location picker.
const Map<String, SearchArea> kSearchCities = {
  'Ongole': SearchArea(
    cityLabel: 'Ongole, Andhra Pradesh',
    latitude: 15.5057,
    longitude: 80.0495,
  ),
  'Guntur': SearchArea(
    cityLabel: 'Guntur, Andhra Pradesh',
    latitude: 16.3067,
    longitude: 80.4365,
  ),
  'Nellore': SearchArea(
    cityLabel: 'Nellore, Andhra Pradesh',
    latitude: 14.4426,
    longitude: 79.9865,
  ),
  'Vijayawada': SearchArea(
    cityLabel: 'Vijayawada, Andhra Pradesh',
    latitude: 16.5062,
    longitude: 80.6480,
  ),
  'Hyderabad': SearchArea(
    cityLabel: 'Hyderabad, Telangana',
    latitude: 17.3850,
    longitude: 78.4867,
  ),
  'Chennai': SearchArea(
    cityLabel: 'Chennai, Tamil Nadu',
    latitude: 13.0827,
    longitude: 80.2707,
  ),
};

const SearchArea kDefaultSearchArea = SearchArea(
  cityLabel: 'Ongole, Andhra Pradesh',
  latitude: 15.5057,
  longitude: 80.0495,
);

/// GPS-derived search area (label is user-facing, coords are live).
SearchArea gpsSearchArea(double latitude, double longitude) => SearchArea(
  cityLabel: 'Current location',
  latitude: latitude,
  longitude: longitude,
);

/// Selected search area for nearby listings.
final searchAreaProvider = StateProvider<SearchArea>(
  (ref) => kDefaultSearchArea,
);

/// Nearby radius in kilometres (drives the home radius chips).
final searchRadiusKmProvider = StateProvider<double>((ref) => 10);

/// Venue repository instance.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  if (!AppConfig.hasSupabaseConfiguration) {
    return DemoVenueRepository();
  }
  final client = ref.watch(supabaseProvider);
  return SupabaseVenueRepository(client);
});

/// Seed venue categories for chips and search filters.
final venueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories();
});

/// Popular venues shown on the home screen.
final popularVenuesProvider = FutureProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).popularVenues(limit: 10);
});

/// Venues near the user's selected search area and radius.
final nearbyVenuesProvider = FutureProvider.autoDispose<List<Venue>>((
  ref,
) async {
  final area = ref.watch(searchAreaProvider);
  final radiusKm = ref.watch(searchRadiusKmProvider);
  return ref
      .watch(venueRepositoryProvider)
      .nearbyVenues(
        latitude: area.latitude,
        longitude: area.longitude,
        maxDistanceKm: radiusKm,
        limit: AppConstants.defaultPageSize ~/ 2,
      );
});

/// Holds the current search query; drives the search results provider.
final searchQueryProvider = StateProvider<VenueSearchQuery>((ref) {
  return const VenueSearchQuery();
});

/// Search results reacting to the current query + home search area / radius.
final searchResultsProvider = FutureProvider<List<Venue>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final area = ref.watch(searchAreaProvider);
  final radiusKm = ref.watch(searchRadiusKmProvider);

  // Inject lat/lng/radius when the user has not overridden them in filters.
  final effective = query.copyWith(
    latitude: () => query.latitude ?? area.latitude,
    longitude: () => query.longitude ?? area.longitude,
    maxDistanceKm: () => query.maxDistanceKm ?? radiusKm,
  );
  return ref.watch(venueRepositoryProvider).search(effective);
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

/// Venue ids the user recently opened (most recent first, capped at 8).
///
/// Kept in memory for the session; drives the Home "Recently viewed" strip.
class RecentlyViewedNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void record(String venueId) {
    if (venueId.isEmpty) return;
    state = [venueId, ...state.where((id) => id != venueId)].take(8).toList();
  }
}

final recentlyViewedIdsProvider =
    NotifierProvider<RecentlyViewedNotifier, List<String>>(
      RecentlyViewedNotifier.new,
    );

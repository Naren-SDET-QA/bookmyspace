import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../location/presentation/location_providers.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';
import '../domain/room_inventory.dart';
import '../domain/room_inventory_repository.dart';
import '../infrastructure/supabase_room_inventory_repository.dart';
import '../infrastructure/supabase_venue_repository.dart';
import '../infrastructure/caching_venue_repository.dart';
import '../../../core/offline/offline_providers.dart';
import '../domain/media_repository.dart';
import '../infrastructure/supabase_media_repository.dart';
import 'category_configuration_providers.dart';

/// Venue repository instance.
///
/// Watches [currentUserProvider] (not the Supabase client's snapshot
/// `currentUser`) so this provider -- and the [CachingVenueRepository.
/// cacheScope] baked into it -- rebuilds on every auth transition
/// (sign-in, sign-out, and switching between accounts) without
/// requiring an app restart. Reading the client snapshot directly would
/// freeze the offline favorites cache scope to whichever user was
/// signed in when this provider was first built, letting a later
/// account read or overwrite the previous account's cached favorites.
final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  return CachingVenueRepository(
    SupabaseVenueRepository(client),
    ref.watch(offlineCacheProvider),
    cacheScope: userId,
  );
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return SupabaseMediaRepository(ref.watch(supabaseProvider));
});

final roomInventoryRepositoryProvider = Provider<RoomInventoryRepository>((
  ref,
) {
  return SupabaseRoomInventoryRepository(ref.watch(supabaseProvider));
});

final hotelRoomTypesProvider = FutureProvider.autoDispose
    .family<List<HotelRoomType>, String>((ref, venueId) {
      return ref
          .watch(roomInventoryRepositoryProvider)
          .roomTypesForVenue(venueId);
    });

/// Seed venue categories for chips and search filters.
final venueCategoriesProvider = FutureProvider<List<VenueCategory>>((ref) {
  return ref.watch(venueRepositoryProvider).categories();
});

/// Category-scoped Home data. This provider is created and queried only when
/// the corresponding module widget resolves it; Home must not use it for
/// disabled modules. The query remains bounded by the repository contract.
final moduleVenuesProvider = FutureProvider.autoDispose
    .family<List<Venue>, String>((ref, moduleId) async {
      final repository = ref.watch(venueRepositoryProvider);
      final configurations = await ref.watch(
        categoryConfigurationsProvider.future,
      );
      final matching = configurations
          .where(
            (configuration) =>
                configuration.id == moduleId ||
                configuration.slug == moduleId ||
                configuration.sectionId == moduleId,
          )
          .toList(growable: false);
      if (matching.isEmpty) return repository.popularVenues(limit: 10);

      final slugs = matching.map((configuration) => configuration.slug).toSet();
      final pages = await Future.wait(
        slugs.map(
          (slug) => repository.search(VenueSearchQuery(categorySlug: slug)),
        ),
      );
      final unique = <String, Venue>{
        for (final venue in pages.expand((page) => page)) venue.id: venue,
      };
      return unique.values.take(50).toList(growable: false);
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

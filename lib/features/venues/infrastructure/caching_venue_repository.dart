import '../../../core/offline/offline_cache.dart';
import '../domain/venue.dart';
import '../domain/venue_repository.dart';

/// Read-through cache around a live [VenueRepository].
///
/// Mutations and the live fetch path are unchanged. Cached snapshots are used
/// only when the inner repository fails for a connectivity reason.
class CachingVenueRepository implements VenueRepository {
  CachingVenueRepository(this._inner, this._cache, {this.cacheScope});

  final VenueRepository _inner;
  final OfflineCache _cache;
  final String? cacheScope;

  String get _favoritesKey => cacheScope == null || cacheScope!.isEmpty
      ? 'venues.favorites'
      : 'venues.favorites.$cacheScope';

  @override
  Future<List<VenueCategory>> categories() => _inner.categories();

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) {
    return _cache.readThroughVenues(
      '${OfflineCache.popularKey}.$limit',
      () => _inner.popularVenues(limit: limit),
    );
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) {
    return _cache.readThroughVenues(
      '${OfflineCache.nearbyKey}.$latitude,$longitude,$maxDistanceKm,$limit',
      () => _inner.nearbyVenues(
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: maxDistanceKm,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) {
    return _cache.readThroughVenues(
      OfflineCache.searchKey(query),
      () => _inner.search(query),
    );
  }

  @override
  Future<Venue> venueById(String id) {
    return _cache.readThroughVenue(id, () => _inner.venueById(id));
  }

  @override
  Future<List<String>> favoriteIds() => _inner.favoriteIds();

  @override
  Future<List<Venue>> favorites() {
    return _cache.readThroughVenues(_favoritesKey, _inner.favorites);
  }

  @override
  Future<void> addFavorite(String venueId) => _inner.addFavorite(venueId);

  @override
  Future<void> removeFavorite(String venueId) => _inner.removeFavorite(venueId);
}

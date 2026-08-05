import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart'
    show NotFoundException, mapError;
import '../domain/venue.dart';
import '../domain/venue_repository.dart';

/// Supabase-backed [VenueRepository].
///
/// Queries are RLS-safe: venue data is publicly readable, favourites are
/// scoped to the authenticated user.
class SupabaseVenueRepository implements VenueRepository {
  SupabaseVenueRepository(this._client);

  final SupabaseClient _client;

  static const String _venueSelect = '''
    *,
    venue_categories (id, slug, name, icon),
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order),
    venue_facilities (facility, is_available)
  ''';

  @override
  Future<List<VenueCategory>> categories() async {
    try {
      final rows = await _client
          .from('venue_categories')
          .select('*')
          .order('name');
      return rows.map(VenueCategory.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> popularVenues({int limit = 10}) async {
    try {
      final rows = await _client
          .from('venues')
          .select(_venueSelect)
          .eq('is_active', true)
          .order('is_featured', ascending: false)
          .order('rating_count', ascending: false)
          .order('avg_rating', ascending: false)
          .limit(limit);
      return rows.map(Venue.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> nearbyVenues({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 25,
    int limit = 20,
  }) async {
    try {
      final data = await _client.rpc<List<dynamic>>(
        'nearby_venues',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'radius_km': maxDistanceKm,
          'max_rows': limit,
        },
      );
      return data.whereType<Map<String, dynamic>>().map(_fromRow).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> search(VenueSearchQuery query) async {
    try {
      // Prefer nearby RPC when distance sort or radius search is requested.
      if (query.latitude != null &&
          query.longitude != null &&
          (query.sortBy == VenueSortBy.distance ||
              query.maxDistanceKm != null)) {
        final nearby = await nearbyVenues(
          latitude: query.latitude!,
          longitude: query.longitude!,
          maxDistanceKm: query.maxDistanceKm ?? 50,
          limit: 50,
        );
        return nearby.where((v) {
          if (query.query.trim().isNotEmpty &&
              !v.name.toLowerCase().contains(query.query.toLowerCase()) &&
              !v.city.toLowerCase().contains(query.query.toLowerCase())) {
            return false;
          }
          if (query.categorySlug != null &&
              v.category?.slug != query.categorySlug) {
            return false;
          }
          if (query.minPrice != null &&
              v.pricingBaseAmount < query.minPrice!) {
            return false;
          }
          if (query.maxPrice != null &&
              v.pricingBaseAmount > query.maxPrice!) {
            return false;
          }
          return true;
        }).toList();
      }

      var builder = _client
          .from('venues')
          .select(_venueSelect)
          .eq('is_active', true);

      if (query.query.trim().isNotEmpty) {
        builder = builder.textSearch('search_document', query.query.trim());
      }
      if (query.categorySlug != null) {
        builder = builder.filter(
          'venue_categories.slug',
          'eq',
          query.categorySlug,
        );
      }
      if (query.city != null && query.city!.trim().isNotEmpty) {
        builder = builder.ilike('city', '%${query.city!.trim()}%');
      }
      if (query.minPrice != null) {
        builder = builder.gte('pricing_base_amount', query.minPrice!);
      }
      if (query.maxPrice != null) {
        builder = builder.lte('pricing_base_amount', query.maxPrice!);
      }

      final (orderColumn, ascending) = switch (query.sortBy) {
        VenueSortBy.priceAsc => ('pricing_base_amount', true),
        VenueSortBy.priceDesc => ('pricing_base_amount', false),
        VenueSortBy.rating => ('avg_rating', false),
        // Distance ordering is handled by the RPC path; fall back to
        // popularity for the REST query.
        VenueSortBy.distance ||
        VenueSortBy.relevance => ('rating_count', false),
      };

      final rows = await builder
          .order(orderColumn, ascending: ascending)
          .limit(50);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Venue> venueById(String id) async {
    try {
      final row = await _client
          .from('venues')
          .select(
            '$_venueSelect, venue_facilities (facility, is_available), '
            'venue_operating_hours (day_of_week, opens_at, closes_at, is_closed)',
          )
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        throw const NotFoundException('Venue not found', code: 'not_found');
      }
      return Venue.fromJson(row);
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw mapError(e);
    }
  }

  @override
  Future<List<String>> favoriteIds() async {
    try {
      final rows = await _client.from('favorites').select('venue_id');
      return rows.map((r) => r['venue_id'] as String).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Venue>> favorites() async {
    try {
      final ids = await favoriteIds();
      if (ids.isEmpty) return const [];
      final rows = await _client
          .from('venues')
          .select(_venueSelect)
          .inFilter('id', ids)
          .eq('is_active', true);
      return rows.map(Venue.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> addFavorite(String venueId) async {
    try {
      await _client.from('favorites').insert({'venue_id': venueId});
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> removeFavorite(String venueId) async {
    try {
      await _client.from('favorites').delete().eq('venue_id', venueId);
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Maps an RPC row (which lacks embedded collections) to a [Venue].
  Venue _fromRow(Map<String, dynamic> row) => Venue.fromJson(row);
}

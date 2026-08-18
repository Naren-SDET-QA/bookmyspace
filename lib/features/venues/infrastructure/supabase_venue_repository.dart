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
    venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order)
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
      String? categoryId;
      if (query.categorySlug != null) {
        final catRow = await _client
            .from('venue_categories')
            .select('id')
            .eq('slug', query.categorySlug!)
            .maybeSingle();
        categoryId = catRow?['id'] as String?;
      }

      // Use inner join syntax on venue_categories when filtering by category to avoid PostgREST 42803 grouping errors
      final selectClause = (query.categorySlug != null)
          ? '''
            *,
            venue_categories!inner (id, slug, name, icon),
            venue_images (id, url, thumbnail_url, alt_text, is_cover, sort_order)
          '''
          : _venueSelect;

      var builder = _client
          .from('venues')
          .select(selectClause)
          .eq('is_active', true);

      if (query.query.trim().isNotEmpty) {
        builder = builder.textSearch('search_document', query.query.trim());
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        // Explicitly cast category_id UUID parameter for PostgREST
        builder = builder.filter('category_id', 'eq', categoryId);
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

      // Log exact SQL executed for function hall / category searches
      if (query.categorySlug != null) {
        final executedSql = "SELECT $selectClause FROM venues WHERE is_active = true"
            " AND category_id = '${categoryId ?? ''}'::uuid"
            "${query.query.trim().isNotEmpty ? " AND search_document @@ to_tsquery('${query.query.trim()}')" : ""}"
            "${query.city != null && query.city!.trim().isNotEmpty ? " AND city ILIKE '%${query.city!.trim()}%'" : ""}"
            " ORDER BY $orderColumn ${ascending ? 'ASC' : 'DESC'} LIMIT 50;";

        ErrorLogger.logMessage(
          'Executing PostgREST Category Search SQL [slug=${query.categorySlug}, category_id=${categoryId ?? 'NULL'}]: $executedSql',
          context: 'SupabaseVenueRepository.search',
        );
      }

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

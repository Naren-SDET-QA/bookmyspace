import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart'
    show NotFoundException, mapError;
import '../../../core/firebase/error_logger.dart';
import '../../home/domain/customer_section_catalog.dart';
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
    id, org_id, category_id, name, slug, description, address_line1,
    address_line2, city, state, postal_code, country, location_node_id, latitude, longitude,
    capacity, pricing_base_amount, pricing_currency, tax_rate,
    parking_capacity, food_options, rules, cancellation_policy, is_verified,
    is_active, avg_rating, rating_count, created_at, updated_at, deleted_at,
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

      // Prefer the additive, indexed RPC when the amenity/search migration is
      // present. The existing REST path remains a safe compatibility fallback
      // for local databases that have not applied it yet.
      try {
        final serverRows = await _client.rpc<List<dynamic>>(
          'search_venues',
          params: {
            'p_query': query.query.trim().isEmpty ? null : query.query.trim(),
            'p_location_node_id': query.locationNodeId,
            'p_lat': query.latitude,
            'p_lng': query.longitude,
            'p_radius_km': query.maxDistanceKm ?? 50,
            'p_category_id': categoryId,
            'p_min_price': query.minPrice,
            'p_max_price': query.maxPrice,
            'p_min_rating': query.minRating,
            'p_min_capacity': query.minCapacity,
            'p_sort': _serverSort(query.sortBy),
            'p_page': 0,
            'p_page_size': 50,
          },
        );
        var serverVenues = serverRows
            .whereType<Map<String, dynamic>>()
            .map(Venue.fromJson)
            .toList();
        final section = CustomerSection.fromId(query.sectionId);
        if (section != null) {
          serverVenues = serverVenues
              .where(
                (v) => CustomerSectionCatalog.matchesVenue(
                  v,
                  section,
                  query.categorySlug,
                ),
              )
              .toList();
        }
        return serverVenues
            .where((v) => CustomerSectionCatalog.matchesFilters(v, query))
            .toList();
      } catch (_) {
        // Older/local schemas continue through the existing REST implementation.
      }

      // Use inner join syntax on venue_categories when filtering by category to avoid PostgREST 42803 grouping errors
      final selectClause = (query.categorySlug != null)
          ? '''
            id, org_id, category_id, name, slug, description, address_line1,
            address_line2, city, state, postal_code, country, location_node_id, latitude, longitude,
            capacity, pricing_base_amount, pricing_currency, tax_rate,
            parking_capacity, food_options, rules, cancellation_policy, is_verified,
            is_active, avg_rating, rating_count, created_at, updated_at, deleted_at,
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
      if (query.locationNodeId != null && query.locationNodeId!.isNotEmpty) {
        try {
          final descendantRows = await _client.rpc<List<dynamic>>(
            'get_location_descendants',
            params: {'p_location_id': query.locationNodeId},
          );
          final ids = descendantRows
              .whereType<Map<String, dynamic>>()
              .map((row) => row['id'] as String?)
              .whereType<String>()
              .toList();
          builder = ids.isEmpty
              ? builder.eq('location_node_id', query.locationNodeId!)
              : builder.inFilter('location_node_id', ids);
        } catch (_) {
          // Keep DEV/older schemas compatible until the additive RPC is
          // deployed; exact-node filtering remains safe fallback behavior.
          builder = builder.eq('location_node_id', query.locationNodeId!);
        }
      }
      if (query.country != null && query.country!.trim().isNotEmpty) {
        builder = builder.ilike('country', '%${query.country!.trim()}%');
      }
      if (query.state != null && query.state!.trim().isNotEmpty) {
        builder = builder.ilike('state', '%${query.state!.trim()}%');
      }
      if (query.district != null && query.district!.trim().isNotEmpty) {
        builder = builder.ilike('address_line1', '%${query.district!.trim()}%');
      }
      if (query.city != null && query.city!.trim().isNotEmpty) {
        builder = builder.ilike('city', '%${query.city!.trim()}%');
      }
      if (query.area != null && query.area!.trim().isNotEmpty) {
        builder = builder.ilike('address_line1', '%${query.area!.trim()}%');
      }
      if (query.postalCode != null && query.postalCode!.trim().isNotEmpty) {
        builder = builder.ilike('postal_code', '%${query.postalCode!.trim()}%');
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
        final executedSql =
            "SELECT $selectClause FROM venues WHERE is_active = true"
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
      var venues = rows
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList();
      final section = CustomerSection.fromId(query.sectionId);
      if (section != null) {
        venues = venues
            .where(
              (v) => CustomerSectionCatalog.matchesVenue(
                v,
                section,
                query.categorySlug,
              ),
            )
            .toList();
      }
      // Section-specific fields (guests, rating, room type, gender,
      // sharing, food, deposit, class type, mode) are evaluated client-side
      // against the same keyword haystack used by the catalog, so no schema
      // change is required.
      venues = venues
          .where((v) => CustomerSectionCatalog.matchesFilters(v, query))
          .toList();

      // Attach distance from the PostGIS RPC when the query is geolocated,
      // and honour the distance sort without touching the schema.
      if (query.hasLocation && venues.isNotEmpty) {
        try {
          final nearby = await _client.rpc<List<dynamic>>(
            'nearby_venues',
            params: {
              'p_lat': query.latitude!,
              'p_lng': query.longitude!,
              'radius_km': query.maxDistanceKm ?? 50,
              'max_rows': 200,
            },
          );
          final distanceById = <String, double>{
            for (final row in nearby.whereType<Map<String, dynamic>>())
              if (row['id'] is String)
                row['id'] as String:
                    (row['distance_km'] as num?)?.toDouble() ?? 0,
          };
          venues = [
            for (final v in venues)
              if (distanceById[v.id] != null &&
                  distanceById[v.id]! <= (query.maxDistanceKm ?? 50))
                v.copyWith(distanceKm: distanceById[v.id]),
          ];
        } catch (e) {
          // Distance is an enhancement; a failing RPC must not break search.
          ErrorLogger.logMessage(
            'Distance lookup skipped: $e',
            context: 'SupabaseVenueRepository.search.distance',
          );
        }
      }
      if (query.sortBy == VenueSortBy.distance) {
        venues.sort((a, b) {
          final da = a.distanceKm ?? double.maxFinite;
          final db = b.distanceKm ?? double.maxFinite;
          return da.compareTo(db);
        });
      }
      return venues;
    } catch (e) {
      throw mapError(e);
    }
  }

  String _serverSort(VenueSortBy sort) => switch (sort) {
    VenueSortBy.distance => 'nearest',
    VenueSortBy.priceAsc => 'lowest_price',
    VenueSortBy.priceDesc => 'highest_price',
    VenueSortBy.rating => 'highest_rating',
    VenueSortBy.relevance => 'recommended',
  };

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
  Venue _fromRow(Map<String, dynamic> row) {
    final safe = Map<String, dynamic>.from(row)..remove('contact_whatsapp');
    return Venue.fromJson(safe);
  }
}

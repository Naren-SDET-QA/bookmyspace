import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exceptions.dart' show mapError;
import '../../venues/domain/venue.dart';
import '../domain/owner_venue_repository.dart';

/// Supabase-backed [OwnerVenueRepository].
class SupabaseOwnerVenueRepository implements OwnerVenueRepository {
  SupabaseOwnerVenueRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Venue>> myVenues() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('get_owner_venues');
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Venue.fromJson)
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
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
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'create_owner_venue',
        params: {
          'p_name': name,
          'p_category_id': categoryId,
          'p_description': description,
          'p_city': city,
          'p_state': state,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_capacity': capacity,
          'p_pricing_base_amount': pricingBaseAmount,
        },
      );
      return Venue.fromJson(data);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
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
  }) async {
    try {
      final data = await _client.rpc<Map<String, dynamic>>(
        'update_owner_venue',
        params: {
          'p_venue_id': venueId,
          'p_name': ?name,
          'p_category_id': ?categoryId,
          'p_description': ?description,
          'p_city': ?city,
          'p_state': ?state,
          'p_latitude': ?latitude,
          'p_longitude': ?longitude,
          'p_capacity': ?capacity,
          'p_pricing_base_amount': ?pricingBaseAmount,
          'p_is_active': ?isActive,
        },
      );
      return Venue.fromJson(data);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    try {
      await _client.rpc<void>(
        'delete_owner_venue',
        params: {'p_venue_id': venueId},
      );
    } catch (e) {
      throw mapError(e);
    }
  }
}

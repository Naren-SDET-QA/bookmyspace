import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/india_pin.dart';
import '../domain/location_node.dart';
import '../domain/location_query_bounds.dart';
import '../domain/location_repository.dart';

class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository(this._client);
  final SupabaseClient _client;

  Future<LocationNode> submitNode({
    required String name,
    required String normalizedName,
    required String level,
    required String countryCode,
    String? parentId,
    String? timezone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in required');
    final row = await _client
        .from('location_nodes')
        .insert({
          'name': name.trim(),
          'normalized_name': normalizedName.trim().toLowerCase(),
          'level': level,
          'country_code': countryCode,
          'parent_id': parentId,
          'timezone': timezone,
          'created_by': userId,
          'updated_by': userId,
          'status': 'pending',
        })
        .select()
        .single();
    return LocationNode.fromJson(row);
  }

  Future<void> updatePendingNode(String id, Map<String, dynamic> values) async {
    await _client.from('location_nodes').update(values).eq('id', id);
  }

  Future<void> setNodeStatus(String id, String status) async {
    await _client
        .from('location_nodes')
        .update({
          'status': status,
          if (status == 'active')
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          if (status == 'inactive') 'approved_at': null,
        })
        .eq('id', id);
  }

  Future<void> mergeNode(String sourceId, String targetId) async {
    await _client
        .from('location_nodes')
        .update({'status': 'merged', 'merged_into_id': targetId})
        .eq('id', sourceId);
  }

  Future<List<LocationNode>> managementSearch(String query) async {
    var request = _client.from('location_nodes').select('*');
    if (query.trim().isNotEmpty) {
      request = request.or(
        'name.ilike.%${query.trim()}%,normalized_name.ilike.%${query.trim()}%',
      );
    }
    final rows = await request.order('name').limit(100);
    return rows.map(LocationNode.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> aliases(String locationId) async {
    final rows = await _client
        .from('location_aliases')
        .select('*')
        .eq('location_id', locationId)
        .order('alias');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addAlias({
    required String locationId,
    required String alias,
    String locale = 'en',
  }) async {
    await _client.from('location_aliases').insert({
      'location_id': locationId,
      'alias': alias.trim(),
      'normalized_alias': alias.trim().toLowerCase(),
      'locale': locale,
    });
  }

  Future<void> removeAlias(String aliasId) async {
    await _client.from('location_aliases').delete().eq('id', aliasId);
  }

  Future<List<Map<String, dynamic>>> history(String locationId) async {
    final rows = await _client
        .from('location_change_history')
        .select('*')
        .eq('location_id', locationId)
        .order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> associatedVenues(String locationId) async {
    final rows = await _client
        .from('venues')
        .select('id, name, city, state, country, is_active')
        .eq('location_node_id', locationId)
        .order('name')
        .limit(100);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> rejectSuggestion(String suggestionId, String reason) async {
    await _client
        .from('location_suggestions')
        .update({
          'status': 'rejected',
          'rejection_reason': reason.trim(),
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', suggestionId);
  }

  @override
  Future<List<LocationNode>> children({
    String? parentId,
    required LocationNodeLevel level,
    int limit = LocationQueryBounds.childrenPageSize,
    int offset = 0,
  }) async {
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.childrenPageSize,
    );
    final end = offset + bounded - 1;
    Future<List<Map<String, dynamic>>> query({
      required bool approvedOnly,
    }) async {
      var request = _client
          .from('location_nodes')
          .select('*')
          .eq('level', _levelValue(level))
          .eq('status', 'active');
      if (approvedOnly) request = request.not('approved_at', 'is', null);
      if (parentId == null) {
        return (await request
                .isFilter('parent_id', null)
                .order('name')
                .range(offset, end))
            .cast<Map<String, dynamic>>();
      }
      return (await request
              .eq('parent_id', parentId)
              .order('name')
              .range(offset, end))
          .cast<Map<String, dynamic>>();
    }

    List<Map<String, dynamic>> data;
    try {
      data = await query(approvedOnly: true);
    } catch (_) {
      data = await query(approvedOnly: false);
    }
    return data.map(LocationNode.fromJson).toList();
  }

  @override
  Future<List<LocationNode>> search(
    String query, {
    String? countryCode,
    LocationNodeLevel? level,
    int limit = LocationQueryBounds.searchPageSize,
    int offset = 0,
  }) async {
    final pin = IndiaPin.normalize(query);
    if (pin != null) {
      return lookupPin(pin, limit: limit, offset: offset);
    }
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.searchPageSize,
    );
    var request = _client
        .from('location_nodes')
        .select('*')
        .eq('status', 'active')
        .not('approved_at', 'is', null)
        .or('name.ilike.%$query%,normalized_name.ilike.%$query%');
    if (countryCode != null && countryCode.isNotEmpty) {
      request = request.eq('country_code', countryCode);
    }
    if (level != null && level != LocationNodeLevel.unknown) {
      request = request.eq('level', _levelValue(level));
    }
    final data = await request
        .order('name')
        .range(offset, offset + bounded - 1);
    return data.map(LocationNode.fromJson).toList();
  }

  @override
  Future<List<LocationNode>> lookupPin(
    String pin, {
    int limit = LocationQueryBounds.pinPageSize,
    int offset = 0,
  }) async {
    final normalized = IndiaPin.normalize(pin);
    if (normalized == null) return const [];
    final bounded = LocationQueryBounds.clamp(
      limit,
      cap: LocationQueryBounds.pinPageSize,
    );
    final linkRows = await _client
        .from('location_postal_codes')
        .select('location_id')
        .eq('postal_code', normalized)
        .order('location_id')
        .range(offset, offset + bounded - 1);
    final ids = <String>{
      for (final row in linkRows)
        if (row['location_id'] is String) row['location_id'] as String,
    };
    if (ids.isNotEmpty) {
      final rows = await _client
          .from('location_nodes')
          .select('*')
          .inFilter('id', ids.toList())
          .eq('status', 'active')
          .not('approved_at', 'is', null)
          .order('name')
          .range(0, bounded - 1);
      return rows.map(LocationNode.fromJson).toList();
    }
    if (offset != 0) return const [];
    final data = await _client
        .from('location_nodes')
        .select('*')
        .eq('status', 'active')
        .not('approved_at', 'is', null)
        .or(
          'metadata->>postal_code.eq.$normalized,'
          'metadata->>pincode.eq.$normalized,'
          'metadata->postal_codes.cs.{$normalized}',
        )
        .order('name')
        .range(offset, offset + bounded - 1);
    return data.map(LocationNode.fromJson).toList();
  }

  @override
  Future<List<LocationNode>> path(String locationId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_location_path',
        params: {'p_location_id': locationId, 'p_max_depth': 32},
      );
      final parsed =
          rows
              .whereType<Map<String, dynamic>>()
              .map(
                (row) => MapEntry(
                  (row['depth'] as num?)?.toInt() ?? 0,
                  LocationNode.fromJson(
                    Map<String, dynamic>.from(row['node'] as Map),
                  ),
                ),
              )
              .toList()
            ..sort((a, b) => b.key.compareTo(a.key));
      if (parsed.isNotEmpty) {
        return parsed.map((entry) => entry.value).toList(growable: false);
      }
    } catch (_) {
      // Keep compatibility with environments where the optional RPC
      // migration has not been applied yet.
    }

    return _pathLegacy(locationId);
  }

  Future<List<LocationNode>> _pathLegacy(String locationId) async {
    final result = <LocationNode>[];
    String? currentId = locationId;
    while (currentId != null) {
      final row = await _client
          .from('location_nodes')
          .select('*')
          .eq('id', currentId)
          .maybeSingle();
      if (row == null) break;
      final node = LocationNode.fromJson(row);
      result.add(node);
      currentId = node.parentId;
    }
    return result.reversed.toList();
  }

  String _levelValue(LocationNodeLevel level) => switch (level) {
    LocationNodeLevel.unknown => 'unknown',
    LocationNodeLevel.country => 'country',
    LocationNodeLevel.stateProvince => 'state_province',
    LocationNodeLevel.districtCounty => 'district_county',
    LocationNodeLevel.mandalTalukTehsilBlock => 'mandal_taluk_tehsil_block',
    LocationNodeLevel.cityTown => 'city_town',
    LocationNodeLevel.village => 'village',
    LocationNodeLevel.areaLocality => 'area_locality',
  };
}

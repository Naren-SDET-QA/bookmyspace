import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/location_node.dart';
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
  }) async {
    final base = _client
        .from('location_nodes')
        .select('*')
        .eq('level', _levelValue(level))
        .eq('status', 'active')
        .not('approved_at', 'is', null);
    final data = parentId == null
        ? await base.isFilter('parent_id', null).order('name')
        : await base.eq('parent_id', parentId).order('name');
    return data.map(LocationNode.fromJson).toList();
  }

  @override
  Future<List<LocationNode>> search(String query, {String? countryCode}) async {
    var request = _client
        .from('location_nodes')
        .select('*')
        .eq('status', 'active')
        .not('approved_at', 'is', null)
        .or('name.ilike.%$query%,normalized_name.ilike.%$query%');
    if (countryCode != null && countryCode.isNotEmpty)
      request = request.eq('country_code', countryCode);
    final data = await request.order('name').limit(25);
    return data.map(LocationNode.fromJson).toList();
  }

  @override
  Future<List<LocationNode>> path(String locationId) async {
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
    LocationNodeLevel.country => 'country',
    LocationNodeLevel.stateProvince => 'state_province',
    LocationNodeLevel.districtCounty => 'district_county',
    LocationNodeLevel.cityTown => 'city_town',
    LocationNodeLevel.areaLocality => 'area_locality',
  };
}

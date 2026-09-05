import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/venue_discovery.dart';

class SupabaseDiscoveryRepository {
  SupabaseDiscoveryRepository(this._client);
  final SupabaseClient _client;
  Future<String> createJob({
    required String state,
    required String city,
    required String category,
  }) async {
    final row = await _client
        .from('venue_discovery_jobs')
        .insert({
          'requested_state': state,
          'requested_city': city,
          'requested_category': category,
          'source': 'osm',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> stage(DiscoveredVenue v, {required String jobId}) async {
    await _client.rpc(
      'stage_discovered_venue',
      params: {
        'p_source': v.source,
        'p_source_place_id': v.sourcePlaceId,
        'p_name': v.name,
        'p_address': v.address,
        'p_city': v.city,
        'p_district': null,
        'p_state': v.state,
        'p_latitude': v.latitude,
        'p_longitude': v.longitude,
        'p_phone': v.phone,
        'p_website': v.website,
        'p_category': v.category,
        'p_source_url': v.sourceUrl,
        'p_raw_metadata': v.rawMetadata,
        'p_job_id': jobId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> pending() async =>
      List<Map<String, dynamic>>.from(
        await _client
            .from('venue_discovery_staging')
            .select()
            .eq('status', 'PENDING_REVIEW'),
      );

  Future<Map<String, dynamic>> discover({
    required String state,
    required String city,
    required String category,
  }) async {
    final response = await _client.functions.invoke(
      'import-venues',
      body: {'state': state, 'city': city, 'category': category},
    );
    if (response.data is! Map) throw StateError('Venue discovery failed.');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Rows in `venue_discovery_staging` awaiting admin review, regardless of
  /// which client (this app, or the `import-venues` edge function during a
  /// search) staged them.
  Future<List<Map<String, dynamic>>> pendingReview() async =>
      List<Map<String, dynamic>>.from(
        await _client
            .from('venue_discovery_staging')
            .select()
            .eq('status', 'PENDING_REVIEW')
            .order('created_at', ascending: false),
      );

  /// Marks a staging row APPROVED or REJECTED. This does not create a
  /// `venues` row by itself — see [materialize]. Splitting review from
  /// materialization keeps "an admin agreed this looks legitimate" separate
  /// from "a draft venue now exists," so nothing is auto-published.
  Future<void> reviewStaging(String stagingId, {required bool approve}) async {
    await _client.rpc(
      'review_discovered_venue',
      params: {
        'p_staging_id': stagingId,
        'p_action': approve ? 'APPROVE' : 'REJECT',
      },
    );
  }

  /// Materializes a previously-approved staging row into a real `venues`
  /// row. The row is created with `is_verified = false, is_active = false`
  /// (enforced server-side in `approve_discovered_venue`) — it never goes
  /// live on its own; a separate, explicit publish step is still required.
  Future<void> materialize(String stagingId) async {
    await _client.rpc(
      'approve_discovered_venue',
      params: {'p_staging_id': stagingId},
    );
  }
}

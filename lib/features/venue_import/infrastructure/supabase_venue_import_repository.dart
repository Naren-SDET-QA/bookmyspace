import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exceptions.dart' show mapError;
import '../domain/venue_import_models.dart';
import '../domain/venue_import_repository.dart';

class SupabaseVenueImportRepository implements VenueImportRepository {
  SupabaseVenueImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<VenueImportCategoryMapping>> categoryMappings({
    bool activeOnly = true,
  }) async {
    try {
      var query = _client.from('venue_import_category_mappings').select('*');
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('display_name');
      return rows.map(VenueImportCategoryMapping.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueImportCategoryMapping> setCategoryActive({
    required String categorySlug,
    required bool isActive,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_set_venue_import_category_active',
        params: {
          'p_category_slug': categorySlug,
          'p_is_active': isActive,
        },
      );
      return VenueImportCategoryMapping.fromJson(
        Map<String, dynamic>.from(row as Map),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueImportJob> createJob({
    required String country,
    required String state,
    required String categorySlug,
    String source = 'osm',
    String? district,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_create_venue_import_job',
        params: {
          'p_country': country,
          'p_state': state,
          'p_category_slug': categorySlug,
          'p_source': source,
          'p_district': district,
        },
      );
      return VenueImportJob.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> triggerFetch({
    String? jobId,
    String? country,
    String? state,
    String? district,
    String? categorySlug,
    bool enrichWithPlaces = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'enrich_with_places': enrichWithPlaces,
      };
      if (jobId != null) body['job_id'] = jobId;
      if (country != null) body['country'] = country;
      if (state != null) body['state'] = state;
      if (district != null) body['district'] = district;
      if (categorySlug != null) body['category_slug'] = categorySlug;

      final response = await _client.functions.invoke(
        'import-venues',
        body: body,
      );

      if (response.status != 200) {
        throw StateError(
          'import-venues failed (${response.status}): ${response.data}',
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<VenueImportJob>> recentJobs({int limit = 20}) async {
    try {
      final rows = await _client
          .from('venue_import_jobs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(VenueImportJob.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<VenueImportStagingRow>> stagingForJob(String jobId) async {
    try {
      final rows = await _client
          .from('venue_import_staging')
          .select('*')
          .eq('job_id', jobId)
          .order('name');
      return rows.map(VenueImportStagingRow.fromJson).toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueImportStagingRow> reviewStaging({
    required String stagingId,
    required bool approve,
    String? notes,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_review_staging_venue',
        params: {
          'p_staging_id': stagingId,
          'p_approve': approve,
          'p_notes': notes,
        },
      );
      return VenueImportStagingRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueImportStagingRow> updateStagingDraft({
    required String stagingId,
    required String name,
    String? addressLine1,
    String? city,
    String? state,
    String? phone,
    String? website,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name.trim(),
        if (addressLine1 != null) 'address_line1': addressLine1,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final rows = await _client
          .from('venue_import_staging')
          .update(payload)
          .eq('id', stagingId)
          .select()
          .limit(1);
      if (rows.isEmpty) {
        throw StateError('staging_not_found');
      }
      return VenueImportStagingRow.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueImportStagingRow> enrichStaging({
    required String stagingId,
    required Map<String, dynamic> enrichment,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_enrich_staging_venue',
        params: {
          'p_staging_id': stagingId,
          'p_enrichment': enrichment,
        },
      );
      return VenueImportStagingRow.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<String> publishStaging(String stagingId) async {
    try {
      final row = await _client.rpc(
        'admin_publish_staged_venue',
        params: {'p_staging_id': stagingId},
      );
      final venue = Map<String, dynamic>.from(row as Map);
      return venue['id'] as String? ?? '';
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueClaim> submitClaim({
    required String venueId,
    Map<String, dynamic>? evidence,
  }) async {
    try {
      final row = await _client.rpc(
        'submit_venue_claim',
        params: {
          'p_venue_id': venueId,
          'p_evidence': evidence ?? {},
        },
      );
      return VenueClaim.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<VenueClaim>> listPendingClaims() async {
    try {
      final rows = await _client.rpc('admin_list_pending_venue_claims');
      final list = rows as List<dynamic>;
      return list
          .map((e) => VenueClaim.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VenueClaim> reviewClaim({
    required String claimId,
    required bool approve,
    String? notes,
  }) async {
    try {
      final row = await _client.rpc(
        'admin_review_venue_claim',
        params: {
          'p_claim_id': claimId,
          'p_approve': approve,
          'p_notes': notes,
        },
      );
      return VenueClaim.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      throw mapError(e);
    }
  }
}

/// Repository provider helper — requires Supabase configuration.
bool venueImportAvailable() => AppConfig.hasSupabaseConfiguration;

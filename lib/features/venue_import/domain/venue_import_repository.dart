import 'venue_import_models.dart';

abstract class VenueImportRepository {
  /// When [activeOnly] is false, includes disabled categories (admin toggle UI).
  Future<List<VenueImportCategoryMapping>> categoryMappings({
    bool activeOnly = true,
  });

  Future<VenueImportCategoryMapping> setCategoryActive({
    required String categorySlug,
    required bool isActive,
  });

  Future<VenueImportJob> createJob({
    required String country,
    required String state,
    required String categorySlug,
    String source = 'osm',
    String? district,
  });

  Future<Map<String, dynamic>> triggerFetch({
    String? jobId,
    String? country,
    String? state,
    String? district,
    String? categorySlug,
    bool enrichWithPlaces = false,
  });

  Future<List<VenueImportJob>> recentJobs({int limit = 20});

  Future<List<VenueImportStagingRow>> stagingForJob(String jobId);

  Future<VenueImportStagingRow> reviewStaging({
    required String stagingId,
    required bool approve,
    String? notes,
  });

  /// Admin preview edits on a staged row (before publish). Provenance fields locked.
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
  });

  /// Apply Google Places enrichment to a staged row (status stays pending_review).
  Future<VenueImportStagingRow> enrichStaging({
    required String stagingId,
    required Map<String, dynamic> enrichment,
  });

  Future<String> publishStaging(String stagingId);

  Future<VenueClaim> submitClaim({
    required String venueId,
    Map<String, dynamic>? evidence,
  });

  Future<List<VenueClaim>> listPendingClaims();

  Future<VenueClaim> reviewClaim({
    required String claimId,
    required bool approve,
    String? notes,
  });
}

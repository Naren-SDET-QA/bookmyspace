import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/venue_discovery_pipeline.dart';
import '../domain/venue_discovery_provider.dart';
import '../domain/venue_enrichment_service.dart';
import '../domain/venue_import_geo_config.dart';
import '../domain/venue_import_models.dart';
import '../domain/venue_import_repository.dart';
import '../infrastructure/noop_venue_discovery_provider.dart';
import '../infrastructure/noop_venue_enrichment_provider.dart';
import '../infrastructure/osm_venue_discovery_provider.dart';
import '../infrastructure/supabase_venue_import_repository.dart';

final venueImportRepositoryProvider = Provider<VenueImportRepository>((ref) {
  return SupabaseVenueImportRepository(ref.watch(supabaseProvider));
});

/// Phase 3 discovery provider — defaults to noop; live OSM via factory helpers.
final venueDiscoveryProvider = Provider<VenueDiscoveryProvider>((ref) {
  return const NoopVenueDiscoveryProvider();
});

/// Live OSM provider for district / category batches (Phase 6–7).
VenueDiscoveryProvider osmDiscoveryForDistrict(
  String district, {
  int limit = 25,
  String country = 'India',
  String state = 'Andhra Pradesh',
}) {
  final bbox = importDistrictConfig(country, state, district)?.bbox ??
      OsmVenueDiscoveryProvider.andhraDistrictBboxes[district];
  return OsmVenueDiscoveryProvider(limit: limit, bbox: bbox);
}

final venueDiscoveryPipelineProvider = Provider<VenueDiscoveryPipeline>((ref) {
  return VenueDiscoveryPipeline(ref.watch(venueDiscoveryProvider));
});

/// Places enrichment — optional; noop until key configured in provider.
final venueEnrichmentServiceProvider = Provider<VenueEnrichmentService>((ref) {
  return VenueEnrichmentService(const NoopVenueEnrichmentProvider());
});

/// Active categories only (fetchable).
final venueImportCategoryMappingsProvider =
    FutureProvider<List<VenueImportCategoryMapping>>((ref) {
      return ref
          .watch(venueImportRepositoryProvider)
          .categoryMappings(activeOnly: true);
    });

/// All mappings including disabled (admin enable/disable UI).
final venueImportAllCategoryMappingsProvider =
    FutureProvider<List<VenueImportCategoryMapping>>((ref) {
      return ref
          .watch(venueImportRepositoryProvider)
          .categoryMappings(activeOnly: false);
    });

final venueImportRecentJobsProvider = FutureProvider<List<VenueImportJob>>(
  (ref) => ref.watch(venueImportRepositoryProvider).recentJobs(),
);

final venueImportStagingProvider =
    FutureProvider.family<List<VenueImportStagingRow>, String>(
      (ref, jobId) =>
          ref.watch(venueImportRepositoryProvider).stagingForJob(jobId),
    );

/// Wizard: Country → State → District → Category → Review.
class VenueImportWizardState {
  const VenueImportWizardState({
    this.country = 'India',
    this.state = '',
    this.district = '',
    this.categorySlug = '',
    this.jobId = '',
    this.step = 0,
    this.isFetching = false,
    this.fetchError = '',
    this.enrichWithPlaces = false,
    this.runOsmFetch = true,
  });

  final String country;
  final String state;
  final String district;
  final String categorySlug;
  final String jobId;
  final int step;
  final bool isFetching;
  final String fetchError;

  /// Optional Google Places enrichment (server key required).
  final bool enrichWithPlaces;

  /// When true, create job then invoke import-venues OSM fetch.
  final bool runOsmFetch;

  VenueImportWizardState copyWith({
    String? country,
    String? state,
    String? district,
    String? categorySlug,
    String? jobId,
    int? step,
    bool? isFetching,
    String? fetchError,
    bool? enrichWithPlaces,
    bool? runOsmFetch,
  }) =>
      VenueImportWizardState(
        country: country ?? this.country,
        state: state ?? this.state,
        district: district ?? this.district,
        categorySlug: categorySlug ?? this.categorySlug,
        jobId: jobId ?? this.jobId,
        step: step ?? this.step,
        isFetching: isFetching ?? this.isFetching,
        fetchError: fetchError ?? this.fetchError,
        enrichWithPlaces: enrichWithPlaces ?? this.enrichWithPlaces,
        runOsmFetch: runOsmFetch ?? this.runOsmFetch,
      );
}

class VenueImportWizardNotifier extends StateNotifier<VenueImportWizardState> {
  VenueImportWizardNotifier(this._repository)
      : super(const VenueImportWizardState());

  final VenueImportRepository _repository;

  void setCountry(String value) =>
      state = state.copyWith(country: value, state: '', district: '');
  void setState(String value) =>
      state = state.copyWith(state: value, district: '');
  void setDistrict(String value) => state = state.copyWith(district: value);
  void setCategory(String value) => state = state.copyWith(categorySlug: value);
  void setEnrichWithPlaces(bool value) =>
      state = state.copyWith(enrichWithPlaces: value);
  void goToStep(int step) => state = state.copyWith(step: step);

  Future<void> setCategoryActive(String slug, bool isActive) async {
    await _repository.setCategoryActive(
      categorySlug: slug,
      isActive: isActive,
    );
  }

  /// Create import job and optionally run OSM discovery (Places optional).
  Future<void> prepareImportJob() async {
    if (state.state.isEmpty || state.categorySlug.isEmpty) {
      state = state.copyWith(fetchError: 'Select state and category first.');
      return;
    }
    if (state.district.isEmpty) {
      state = state.copyWith(fetchError: 'Select a district (or Entire state).');
      return;
    }

    state = state.copyWith(isFetching: true, fetchError: '');
    try {
      final districtForJob =
          state.district == kEntireState ? null : state.district;
      final job = await _repository.createJob(
        country: state.country,
        state: state.state,
        district: districtForJob,
        categorySlug: state.categorySlug,
        source: state.enrichWithPlaces ? 'osm+google' : 'osm',
      );

      var fetchNote = '';
      if (state.runOsmFetch) {
        try {
          await _repository.triggerFetch(
            jobId: job.id,
            enrichWithPlaces: state.enrichWithPlaces,
          );
        } catch (e) {
          fetchNote = e.toString();
        }
      }

      state = state.copyWith(
        isFetching: false,
        jobId: job.id,
        step: 4,
        fetchError: fetchNote,
      );
    } catch (e) {
      state = state.copyWith(isFetching: false, fetchError: e.toString());
    }
  }

  @Deprecated('Use prepareImportJob')
  Future<void> fetchVenues() => prepareImportJob();

  Future<void> reviewStaging(String stagingId, bool approve) async {
    await _repository.reviewStaging(stagingId: stagingId, approve: approve);
  }

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
  }) {
    return _repository.updateStagingDraft(
      stagingId: stagingId,
      name: name,
      addressLine1: addressLine1,
      city: city,
      state: state,
      phone: phone,
      website: website,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<String> publishStaging(String stagingId) async {
    return _repository.publishStaging(stagingId);
  }
}

final venueImportWizardProvider =
    StateNotifierProvider<VenueImportWizardNotifier, VenueImportWizardState>(
      (ref) =>
          VenueImportWizardNotifier(ref.watch(venueImportRepositoryProvider)),
    );

/// @Deprecated — use [indianStateNames] / [kImportCountries].
List<String> get indianStates => indianStateNames();

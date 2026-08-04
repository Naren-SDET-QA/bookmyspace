import '../domain/venue_enrichment.dart';
import '../domain/venue_enrichment_provider.dart';

/// No-op enrichment when Google Places API key is not configured.
class NoopVenueEnrichmentProvider implements VenueEnrichmentProvider {
  const NoopVenueEnrichmentProvider();

  @override
  String get sourceCode => 'noop';

  @override
  bool get isConfigured => false;

  @override
  Future<VenueEnrichmentPatch?> enrich(VenueEnrichmentRequest request) async =>
      null;
}

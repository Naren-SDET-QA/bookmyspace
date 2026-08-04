import 'venue_enrichment.dart';

/// Pluggable enrichment for staged venues (Google Places / noop).
///
/// Must not auto-publish — callers persist via admin/service RPC only.
abstract class VenueEnrichmentProvider {
  /// Stable source code (e.g. `google_places`).
  String get sourceCode;

  /// Whether this provider can run (API key configured, etc.).
  bool get isConfigured;

  /// Look up supplemental data for a staged row. No DB writes.
  Future<VenueEnrichmentPatch?> enrich(VenueEnrichmentRequest request);
}

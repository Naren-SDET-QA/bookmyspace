import 'venue_enrichment.dart';
import 'venue_enrichment_provider.dart';
import 'venue_import_models.dart';
import 'venue_import_normalizer.dart';

/// Merge/dedupe enrichment into staged rows; preserves OSM provenance.
class VenueEnrichmentService {
  const VenueEnrichmentService(this._provider);

  final VenueEnrichmentProvider _provider;

  bool needsEnrichment(VenueImportStagingRow row) =>
      VenueEnrichmentRequest.fromStagingRow(row).needsEnrichment;

  /// Fetches enrichment patch (no persistence).
  Future<VenueEnrichmentPatch?> fetchPatch(VenueEnrichmentRequest request) async {
    if (!_provider.isConfigured) return null;
    if (!request.needsEnrichment && request.existingGooglePlaceId.isNotEmpty) {
      return null;
    }
    return _provider.enrich(request);
  }

  /// Pure merge — keeps `source` / `sourcePlaceId`; fills missing fields only.
  VenueImportStagingRow applyPatch({
    required VenueImportStagingRow row,
    required VenueEnrichmentPatch patch,
    Set<String> usedGooglePlaceIds = const {},
  }) {
    if (patch.isEmpty) return row;

    final googleId = patch.googlePlaceId.trim();
    if (googleId.isNotEmpty) {
      final alreadyUsed = usedGooglePlaceIds.contains(googleId) &&
          row.googlePlaceId != googleId;
      if (alreadyUsed) {
        throw VenueEnrichmentException(
          'Google place already linked to another staged row',
          code: 'google_place_id_already_staged',
        );
      }
    }

    final mergedImages = mergeImageRefs(row.imageRefs, patch.imageRefs);
    final phone = row.phone.isEmpty
        ? (normalizeVenuePhone(patch.phone) ?? '')
        : row.phone;
    final website = row.website.isEmpty ? patch.website.trim() : row.website;

    return row.copyWith(
      googlePlaceId: row.googlePlaceId.isEmpty ? googleId : row.googlePlaceId,
      phone: phone,
      website: website,
      imageRefs: mergedImages,
      operatingHours:
          row.operatingHours.isEmpty ? patch.operatingHours : row.operatingHours,
      ratings: row.ratings.isEmpty ? patch.ratings : row.ratings,
      enrichmentProvenance: {
        ...row.enrichmentProvenance,
        ...patch.provenance,
      },
      status: VenueImportStagingStatus.pendingReview,
      source: row.source,
      sourcePlaceId: row.sourcePlaceId,
      fetchedAt: row.fetchedAt,
    );
  }

  /// Dedupe image refs by normalized URL.
  static List<Map<String, dynamic>> mergeImageRefs(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final ref in [...existing, ...incoming]) {
      final url = '${ref['url'] ?? ''}'.trim().toLowerCase();
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      out.add(Map<String, dynamic>.from(ref));
    }
    return out;
  }

  /// Track google_place_id usage across a batch.
  static Set<String> collectGooglePlaceIds(Iterable<VenueImportStagingRow> rows) =>
      rows
          .map((r) => r.googlePlaceId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
}

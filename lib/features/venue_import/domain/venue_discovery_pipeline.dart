import 'venue_discovery.dart';
import 'venue_discovery_provider.dart';
import 'venue_import_geo_config.dart';
import 'venue_import_normalizer.dart';

/// Validates discovery inputs and runs normalize → dedupe with provenance.
class VenueDiscoveryPipeline {
  const VenueDiscoveryPipeline(this._provider);

  final VenueDiscoveryProvider _provider;

  /// Validates Country → State → District → Category (+ optional source).
  void validateQuery(VenueDiscoveryQuery query) {
    final country = query.country.trim();
    final state = query.state.trim();
    final category = query.categorySlug.trim();
    final source = query.sourceCode.trim();

    if (country.isEmpty) {
      throw VenueDiscoveryValidationException(
        'Country is required',
        field: 'country',
      );
    }
    if (state.isEmpty) {
      throw VenueDiscoveryValidationException(
        'State is required',
        field: 'state',
      );
    }
    if (category.isEmpty) {
      throw VenueDiscoveryValidationException(
        'Category is required',
        field: 'categorySlug',
      );
    }
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(category)) {
      throw VenueDiscoveryValidationException(
        'Category must be a slug (e.g. function_hall)',
        field: 'categorySlug',
      );
    }
    if (!VenueDiscoverySources.all.contains(source)) {
      throw VenueDiscoveryValidationException(
        'Unsupported source "$source"',
        field: 'sourceCode',
      );
    }
  }

  /// Normalizes phone/address and fills country/state/category defaults.
  VenueDiscoveryCandidate normalizeCandidate(
    VenueDiscoveryCandidate raw, {
    required VenueDiscoveryQuery query,
    DateTime? fetchedAt,
  }) {
    final at = fetchedAt ?? DateTime.now().toUtc();
    final phone = normalizeVenuePhone(raw.phone) ?? '';
    final address = normalizeVenueAddress(raw.addressLine1) ?? '';
    final name = raw.name.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (name.isEmpty) {
      throw VenueDiscoveryValidationException(
        'Candidate name is required',
        field: 'name',
      );
    }
    if (raw.latitude < -90 ||
        raw.latitude > 90 ||
        raw.longitude < -180 ||
        raw.longitude > 180) {
      throw VenueDiscoveryValidationException(
        'Invalid latitude/longitude',
        field: 'location',
      );
    }

    return raw.copyWith(
      name: name,
      phone: phone,
      addressLine1: address,
      country: raw.country.trim().isEmpty ? query.country.trim() : raw.country.trim(),
      state: raw.state.trim().isEmpty ? query.state.trim() : raw.state.trim(),
      district: raw.district.trim().isEmpty &&
              query.district.trim().isNotEmpty &&
              query.district.trim() != kEntireState
          ? query.district.trim()
          : raw.district.trim(),
      categorySlug: raw.categorySlug.trim().isEmpty
          ? query.categorySlug.trim()
          : raw.categorySlug.trim(),
      provenance: VenueDiscoveryProvenance(
        sourceCode: raw.provenance.sourceCode.trim().isEmpty
            ? query.sourceCode
            : raw.provenance.sourceCode,
        sourcePlaceId: raw.provenance.sourcePlaceId.trim(),
        sourceUrl: raw.provenance.sourceUrl.trim(),
        fetchedAt: raw.provenance.fetchedAt,
        verifiedAt: raw.provenance.verifiedAt,
      ).copyWithFetchedAt(at),
    );
  }

  /// Drops duplicates by source_place_id, then name+lat/lng grid.
  List<VenueDiscoveryCandidate> dedupe(List<VenueDiscoveryCandidate> input) {
    final kept = <VenueDiscoveryCandidate>[];
    final seenPlaceIds = <String>{};
    final seenKeys = <String>{};

    for (final c in input) {
      final placeId = c.sourcePlaceId.trim();
      if (placeId.isNotEmpty) {
        if (seenPlaceIds.contains(placeId)) continue;
        seenPlaceIds.add(placeId);
      }

      final key = dedupeKey(
        name: c.name,
        latitude: c.latitude,
        longitude: c.longitude,
      );
      if (seenKeys.contains(key)) continue;
      seenKeys.add(key);
      kept.add(c);
    }
    return kept;
  }

  /// Validate → discover (dry-run) → normalize → dedupe. No staging writes.
  Future<VenueDiscoveryResult> run(VenueDiscoveryQuery query) async {
    validateQuery(query);
    final fetchedAt = DateTime.now().toUtc();
    final raw = await _provider.discover(query);

    final normalized = <VenueDiscoveryCandidate>[];
    for (final candidate in raw) {
      normalized.add(
        normalizeCandidate(candidate, query: query, fetchedAt: fetchedAt),
      );
    }

    final unique = dedupe(normalized);
    return VenueDiscoveryResult(
      query: query,
      candidates: unique,
      duplicatesDropped: normalized.length - unique.length,
      fetchedAt: fetchedAt,
      sourceCode: query.sourceCode,
    );
  }
}

extension on VenueDiscoveryProvenance {
  VenueDiscoveryProvenance copyWithFetchedAt(DateTime fetchedAt) =>
      VenueDiscoveryProvenance(
        sourceCode: sourceCode,
        fetchedAt: fetchedAt,
        sourcePlaceId: sourcePlaceId,
        sourceUrl: sourceUrl,
        verifiedAt: verifiedAt,
      );
}

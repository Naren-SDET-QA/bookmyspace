import 'venue_discovery.dart';
import 'venue_import_models.dart';
import 'venue_import_normalizer.dart';

/// Published venue snapshot used to enforce owner-verified + dedupe guards.
class PublishedVenueGuard {
  const PublishedVenueGuard({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.source = '',
    this.sourcePlaceId = '',
    this.ownerVerified = false,
    this.ownerVerifiedFields = const [],
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String source;
  final String sourcePlaceId;
  final bool ownerVerified;
  final List<String> ownerVerifiedFields;
}

class OwnerVerifiedProtectionException implements Exception {
  OwnerVerifiedProtectionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StagingReviewException implements Exception {
  StagingReviewException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Phase 4: Review → edit preview → Approve/Reject → Publish (no live fetch).
class VenueStagingReviewService {
  const VenueStagingReviewService();

  /// Applies admin preview edits with phone/address normalization.
  /// Preserves source/provenance fields (source, sourcePlaceId, fetchedAt).
  VenueImportStagingRow applyPreviewEdits({
    required VenueImportStagingRow row,
    required String name,
    String? addressLine1,
    String? city,
    String? state,
    String? phone,
    String? website,
    double? latitude,
    double? longitude,
  }) {
    if (row.status == VenueImportStagingStatus.published) {
      throw StagingReviewException('Published rows cannot be edited');
    }
    if (row.status == VenueImportStagingStatus.duplicate) {
      throw StagingReviewException('Duplicate rows cannot be edited');
    }

    final trimmedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmedName.isEmpty) {
      throw StagingReviewException('Name is required');
    }

    final lat = latitude ?? row.latitude;
    final lng = longitude ?? row.longitude;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      throw StagingReviewException('Invalid latitude/longitude');
    }

    return row.copyWith(
      name: trimmedName,
      addressLine1: normalizeVenueAddress(addressLine1 ?? row.addressLine1) ?? '',
      city: (city ?? row.city).trim(),
      state: (state ?? row.state).trim(),
      phone: normalizeVenuePhone(phone ?? row.phone) ?? '',
      website: (website ?? row.website).trim(),
      latitude: lat,
      longitude: lng,
      // Provenance locked:
      source: row.source,
      sourcePlaceId: row.sourcePlaceId,
      fetchedAt: row.fetchedAt,
    );
  }

  VenueImportStagingRow approve(VenueImportStagingRow row, {String? notes}) {
    if (row.status != VenueImportStagingStatus.pendingReview &&
        row.status != VenueImportStagingStatus.rejected) {
      throw StagingReviewException(
        'Only pending/rejected rows can be approved (got ${row.status.dbValue})',
      );
    }
    return row.copyWith(status: VenueImportStagingStatus.approved);
  }

  VenueImportStagingRow reject(VenueImportStagingRow row, {String? notes}) {
    if (row.status != VenueImportStagingStatus.pendingReview &&
        row.status != VenueImportStagingStatus.approved) {
      throw StagingReviewException(
        'Only pending/approved rows can be rejected (got ${row.status.dbValue})',
      );
    }
    return row.copyWith(status: VenueImportStagingStatus.rejected);
  }

  /// Returns matching published venue if this staging row would collide.
  PublishedVenueGuard? findDuplicatePublished({
    required VenueImportStagingRow row,
    required List<PublishedVenueGuard> published,
  }) {
    for (final p in published) {
      final samePlace = row.sourcePlaceId.isNotEmpty &&
          p.sourcePlaceId.isNotEmpty &&
          row.source == p.source &&
          row.sourcePlaceId == p.sourcePlaceId;
      final sameNameLoc = isLikelyDuplicate(
        nameA: row.name,
        latA: row.latitude,
        lngA: row.longitude,
        nameB: p.name,
        latB: p.latitude,
        lngB: p.longitude,
        placeIdA: row.sourcePlaceId,
        placeIdB: p.sourcePlaceId,
      );
      if (samePlace || sameNameLoc) return p;
    }
    return null;
  }

  /// Publish decision with owner-verified + dedupe protection.
  /// Does not perform network I/O — caller persists the outcome.
  VenueImportStagingRow preparePublish({
    required VenueImportStagingRow row,
    required List<PublishedVenueGuard> published,
    String newVenueId = 'published-local',
  }) {
    if (row.status != VenueImportStagingStatus.approved) {
      throw StagingReviewException('Only approved rows can be published');
    }

    final match = findDuplicatePublished(row: row, published: published);
    if (match != null && match.ownerVerified) {
      throw OwnerVerifiedProtectionException(
        'Refusing overwrite of owner-verified venue ${match.id}',
      );
    }

    // Field-level merge preview for non-verified matches (no overwrite of locked fields).
    if (match != null && match.ownerVerifiedFields.isNotEmpty) {
      final merged = mergeImportRespectingOwnerVerified(
        existing: {
          'name': match.name,
          'latitude': match.latitude,
          'longitude': match.longitude,
        },
        imported: {
          'name': row.name,
          'latitude': row.latitude,
          'longitude': row.longitude,
        },
        ownerVerifiedFields: match.ownerVerifiedFields,
      );
      // Ensure protected name stays when listed.
      if (match.ownerVerifiedFields.contains('name') &&
          merged['name'] != match.name) {
        throw OwnerVerifiedProtectionException(
          'Owner-verified field "name" would be overwritten',
        );
      }
    }

    return row.copyWith(
      status: VenueImportStagingStatus.published,
      publishedVenueId: match?.id ?? newVenueId,
    );
  }

  /// Provenance snapshot for audit UI.
  Map<String, dynamic> provenanceOf(VenueImportStagingRow row) => {
        'source': row.source,
        'source_place_id': row.sourcePlaceId,
        'google_place_id': row.googlePlaceId,
        'enrichment_provenance': row.enrichmentProvenance,
        'fetched_at': row.fetchedAt?.toIso8601String(),
        'category_slug': row.categorySlug,
      };
}

/// Convenience: build a discovery provenance map from staging.
Map<String, dynamic> stagingToProvenanceJson(VenueImportStagingRow row) =>
    VenueDiscoveryProvenance(
      sourceCode: row.source,
      sourcePlaceId: row.sourcePlaceId,
      fetchedAt: row.fetchedAt ?? DateTime.now().toUtc(),
    ).toJson();

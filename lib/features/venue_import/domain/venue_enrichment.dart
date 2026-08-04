/// Phase 6: enrichment contracts for staged OSM venues (Google Places supplement).

import 'venue_import_models.dart';

/// Fields that enrichment may fill when missing on a staged row.
abstract final class VenueEnrichmentFields {
  static const phone = 'phone';
  static const website = 'website';
  static const imageRefs = 'image_refs';
  static const operatingHours = 'operating_hours';
  static const ratings = 'ratings';
  static const googlePlaceId = 'google_place_id';
}

/// Request to enrich a single staged venue.
class VenueEnrichmentRequest {
  const VenueEnrichmentRequest({
    required this.stagingId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.district = '',
    this.state = '',
    this.categorySlug = 'function_hall',
    this.existingPhone = '',
    this.existingWebsite = '',
    this.existingGooglePlaceId = '',
    this.existingImageCount = 0,
    this.existingRatingsEmpty = true,
    this.existingHoursEmpty = true,
  });

  final String stagingId;
  final String name;
  final double latitude;
  final double longitude;
  final String city;
  final String district;
  final String state;
  final String categorySlug;
  final String existingPhone;
  final String existingWebsite;
  final String existingGooglePlaceId;
  final int existingImageCount;
  final bool existingRatingsEmpty;
  final bool existingHoursEmpty;

  factory VenueEnrichmentRequest.fromStagingRow(VenueImportStagingRow row) =>
      VenueEnrichmentRequest(
        stagingId: row.id,
        name: row.name,
        latitude: row.latitude,
        longitude: row.longitude,
        city: row.city,
        district: row.district,
        state: row.state,
        categorySlug: row.categorySlug,
        existingPhone: row.phone,
        existingWebsite: row.website,
        existingGooglePlaceId: row.googlePlaceId,
        existingImageCount: row.imageRefs.length,
        existingRatingsEmpty: row.ratings.isEmpty,
        existingHoursEmpty: row.operatingHours.isEmpty,
      );

  bool get needsEnrichment =>
      existingPhone.isEmpty ||
      existingWebsite.isEmpty ||
      existingImageCount == 0 ||
      existingRatingsEmpty ||
      existingHoursEmpty;
}

/// Supplemental data from Google Places (or other enrichment source).
class VenueEnrichmentPatch {
  const VenueEnrichmentPatch({
    this.googlePlaceId = '',
    this.phone = '',
    this.website = '',
    this.imageRefs = const [],
    this.operatingHours = const [],
    this.ratings = const {},
    this.provenance = const {},
    this.fieldsEnriched = const [],
    this.matchScore = 0,
  });

  final String googlePlaceId;
  final String phone;
  final String website;
  final List<Map<String, dynamic>> imageRefs;
  final List<Map<String, dynamic>> operatingHours;
  final Map<String, dynamic> ratings;
  final Map<String, dynamic> provenance;
  final List<String> fieldsEnriched;
  final double matchScore;

  bool get isEmpty =>
      googlePlaceId.isEmpty &&
      phone.isEmpty &&
      website.isEmpty &&
      imageRefs.isEmpty &&
      operatingHours.isEmpty &&
      ratings.isEmpty;

  Map<String, dynamic> toRpcPayload() => {
        if (googlePlaceId.isNotEmpty) 'google_place_id': googlePlaceId,
        if (phone.isNotEmpty) 'phone': phone,
        if (website.isNotEmpty) 'website': website,
        if (imageRefs.isNotEmpty) 'image_refs': imageRefs,
        if (operatingHours.isNotEmpty) 'operating_hours': operatingHours,
        if (ratings.isNotEmpty) 'ratings': ratings,
        'enrichment_provenance': provenance,
        if (fieldsEnriched.isNotEmpty) 'fields_enriched': fieldsEnriched,
      };
}

class VenueEnrichmentException implements Exception {
  VenueEnrichmentException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$code: $message';
}

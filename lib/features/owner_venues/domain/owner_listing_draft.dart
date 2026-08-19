import 'dart:typed_data';

import '../../home/domain/customer_section_catalog.dart';

/// A gallery item: either an already-hosted URL or local bytes to upload.
class OwnerListingPhoto {
  const OwnerListingPhoto({
    this.remoteUrl = '',
    this.bytes,
    this.fileName = '',
    this.contentType = 'image/jpeg',
  });

  final String remoteUrl;
  final Uint8List? bytes;
  final String fileName;
  final String contentType;

  bool get needsUpload => bytes != null && bytes!.isNotEmpty;

  static const maxBytes = 5 * 1024 * 1024;
  static const allowedTypes = {'image/jpeg', 'image/png', 'image/webp'};
}

/// Owner listing payload used by create and edit.
///
/// Maps onto existing `create_owner_venue` / `update_owner_venue` RPCs
/// plus `venue_images` / `venue_facilities` owner writes and the
/// `venue-images` Storage bucket.
class OwnerListingDraft {
  const OwnerListingDraft({
    required this.name,
    required this.section,
    required this.catalogCategoryId,
    required this.categoryId,
    required this.description,
    required this.city,
    required this.state,
    this.addressLine1 = '',
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.pricingBaseAmount,
    this.photos = const [],
    this.facilities = const [],
    this.publish = false,
  });

  final String name;
  final CustomerSection section;
  final String catalogCategoryId;
  final String categoryId;
  final String description;
  final String city;
  final String state;
  final String addressLine1;
  final double latitude;
  final double longitude;
  final int capacity;
  final double pricingBaseAmount;
  final List<OwnerListingPhoto> photos;
  final List<String> facilities;
  final bool publish;

  static const maxPhotos = 6;
  static const storageBucket = 'venue-images';

  void validate() {
    if (!CustomerSectionCatalog.slugBelongsToSection(
      section,
      catalogCategoryId,
    )) {
      throw StateError('Listing category does not belong to its section.');
    }
    if (photos.length > maxPhotos) {
      throw StateError('A listing can have at most $maxPhotos photos.');
    }
  }
}

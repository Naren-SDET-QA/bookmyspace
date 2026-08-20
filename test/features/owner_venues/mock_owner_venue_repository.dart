import 'package:bookmyspace/features/home/domain/customer_section_catalog.dart';
import 'package:bookmyspace/features/owner_venues/domain/owner_listing_draft.dart';
import 'package:bookmyspace/features/owner_venues/domain/owner_venue_repository.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';

class MockOwnerVenueRepository implements OwnerVenueRepository {
  final List<Venue> venues = [];

  @override
  Future<List<Venue>> myVenues() async => List<Venue>.from(venues);

  @override
  Future<Venue> createVenue({
    required String name,
    required String categoryId,
    required String description,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
    required int capacity,
    required double pricingBaseAmount,
  }) async {
    final venue = Venue(
      id: 'ov_${venues.length + 1}',
      name: name,
      description: description,
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      pricingBaseAmount: pricingBaseAmount,
      isActive: true,
      category: VenueCategory(
        id: categoryId,
        slug: categoryId,
        name: categoryId,
      ),
    );
    venues.insert(0, venue);
    return venue;
  }

  @override
  Future<Venue> updateVenue({
    required String venueId,
    String? name,
    String? categoryId,
    String? description,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    int? capacity,
    double? pricingBaseAmount,
    bool? isActive,
  }) async {
    final index = venues.indexWhere((v) => v.id == venueId);
    if (index < 0) throw StateError('not found');
    final current = venues[index];
    final updated = current.copyWith(
      name: name,
      description: description,
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
      capacity: capacity,
      pricingBaseAmount: pricingBaseAmount,
      isActive: isActive,
      category: categoryId == null
          ? current.category
          : VenueCategory(id: categoryId, slug: categoryId, name: categoryId),
    );
    venues[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteVenue(String venueId) async {
    venues.removeWhere((v) => v.id == venueId);
  }

  @override
  Future<Venue> saveListing({
    String? venueId,
    required OwnerListingDraft draft,
  }) async {
    if (!CustomerSectionCatalog.slugBelongsToSection(
          draft.section,
          draft.catalogCategoryId,
        ) &&
        CustomerSectionCatalog.fromAny(draft.catalogCategoryId) !=
            draft.section) {
      throw StateError('Wrong-section category');
    }
    final images = [
      for (var i = 0; i < draft.photos.length; i++)
        VenueImage(
          id: 'img_$i',
          url: draft.photos[i].needsUpload
              ? 'https://example.com/uploads/${draft.photos[i].fileName}'
              : draft.photos[i].remoteUrl,
          isCover: i == 0,
          sortOrder: i,
        ),
    ];
    final facilities = draft.facilities
        .map((name) => VenueFacility(facility: name))
        .toList();
    if (venueId == null) {
      final venue = Venue(
        id: 'ov_${venues.length + 1}',
        name: draft.name,
        description: draft.description,
        addressLine1: draft.addressLine1,
        city: draft.city,
        state: draft.state,
        latitude: draft.latitude,
        longitude: draft.longitude,
        capacity: draft.capacity,
        pricingBaseAmount: draft.pricingBaseAmount,
        isActive: draft.publish,
        category: VenueCategory(
          id: draft.categoryId,
          slug: CustomerSectionCatalog.persistableCategorySlug(
            draft.section,
            draft.catalogCategoryId,
          ),
          name: draft.catalogCategoryId,
        ),
        images: images,
        facilities: facilities,
      );
      venues.insert(0, venue);
      return venue;
    }
    final index = venues.indexWhere((v) => v.id == venueId);
    if (index < 0) throw StateError('not found');
    final updated = venues[index].copyWith(
      name: draft.name,
      description: draft.description,
      addressLine1: draft.addressLine1,
      city: draft.city,
      state: draft.state,
      latitude: draft.latitude,
      longitude: draft.longitude,
      capacity: draft.capacity,
      pricingBaseAmount: draft.pricingBaseAmount,
      isActive: draft.publish,
      category: VenueCategory(
        id: draft.categoryId,
        slug: CustomerSectionCatalog.persistableCategorySlug(
          draft.section,
          draft.catalogCategoryId,
        ),
        name: draft.catalogCategoryId,
      ),
      images: images,
      facilities: facilities,
    );
    venues[index] = updated;
    return updated;
  }

  @override
  Future<Venue> setPublished(String venueId, bool published) async {
    final index = venues.indexWhere((v) => v.id == venueId);
    if (index < 0) throw StateError('not found');
    venues[index] = venues[index].copyWith(isActive: published);
    return venues[index];
  }

  @override
  Future<void> setLocationNode(String venueId, String locationNodeId) async {}

  @override
  Future<void> replaceImages(String venueId, List<String> imageUrls) async {
    final index = venues.indexWhere((v) => v.id == venueId);
    if (index < 0) return;
    venues[index] = venues[index].copyWith(
      images: [
        for (var i = 0; i < imageUrls.length; i++)
          VenueImage(
            id: 'img_$i',
            url: imageUrls[i],
            isCover: i == 0,
            sortOrder: i,
          ),
      ],
    );
  }

  @override
  Future<String> uploadPhoto({
    required String venueId,
    required List<int> bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    return 'https://example.com/uploads/$fileName';
  }

  @override
  Future<void> replaceFacilities(
    String venueId,
    List<String> facilities,
  ) async {
    final index = venues.indexWhere((v) => v.id == venueId);
    if (index < 0) return;
    venues[index] = venues[index].copyWith(
      facilities: facilities
          .map((name) => VenueFacility(facility: name))
          .toList(),
    );
  }
}

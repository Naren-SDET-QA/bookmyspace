import 'content_models.dart';

abstract class AdminContentRepository {
  Future<HomepageContentConfig> homepageConfig();

  Future<List<HomepageSection>> listHomepageSections({bool includeHidden = true});

  Future<List<HomeCategoryTile>> listCategoryTiles({bool includeHidden = true});

  Future<List<AdminContentVenue>> listVenues({String? query, int limit = 50});

  Future<AdminContentVenue> updateVenueContent(
    String venueId,
    Map<String, dynamic> patch,
  );

  Future<int> replaceVenueImages(String venueId, List<Map<String, dynamic>> images);

  Future<int> setVenueAmenities(String venueId, List<String> amenities);

  Future<HomepageSection> upsertHomepageSection({
    required String sectionKey,
    required String title,
    String? emoji,
    int? sortOrder,
    bool? isVisible,
    Map<String, dynamic>? config,
  });

  Future<int> reorderHomepageSections(List<String> orderedKeys);

  Future<HomeCategoryTile> upsertCategoryTile({
    required String tileKey,
    required String label,
    required String emoji,
    required String routeTarget,
    int? sortOrder,
    bool? isVisible,
  });

  Future<Map<String, dynamic>> updateCategoryDisplay({
    required String categoryId,
    String? displayName,
    String? icon,
    int? sortOrder,
    bool? isHomeVisible,
  });

  Future<Map<String, dynamic>> setPlatformSetting({
    required String key,
    required Map<String, dynamic> value,
    String? description,
  });

  Future<Map<String, dynamic>> setOrgCommission({
    required String orgId,
    required double commissionRate,
  });
}

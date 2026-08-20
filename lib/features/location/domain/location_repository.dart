import 'location_node.dart';

abstract interface class LocationRepository {
  Future<List<LocationNode>> children({
    String? parentId,
    required LocationNodeLevel level,
  });
  Future<List<LocationNode>> search(String query, {String? countryCode});
  Future<List<LocationNode>> path(String locationId);
}

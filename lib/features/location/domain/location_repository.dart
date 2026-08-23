import 'location_node.dart';
import 'location_query_bounds.dart';

abstract interface class LocationRepository {
  Future<List<LocationNode>> children({
    String? parentId,
    required LocationNodeLevel level,
    int limit = LocationQueryBounds.childrenPageSize,
    int offset = 0,
  });
  Future<List<LocationNode>> search(
    String query, {
    String? countryCode,
    LocationNodeLevel? level,
    int limit = LocationQueryBounds.searchPageSize,
    int offset = 0,
  });
  Future<List<LocationNode>> lookupPin(
    String pin, {
    int limit = LocationQueryBounds.pinPageSize,
    int offset = 0,
  });
  Future<List<LocationNode>> path(String locationId);
}

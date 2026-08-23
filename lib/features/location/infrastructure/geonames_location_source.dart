import '../domain/location_node.dart';

/// Optional coordinate/timezone enrichment. Never creates geography.
class GeoNamesLocationSource {
  const GeoNamesLocationSource();

  List<LocationNode> enrich({
    required List<LocationNode> nodes,
    required List<Map<String, String>> rows,
  }) {
    final byName = <String, LocationNode>{
      for (final node in nodes) node.normalizedName: node,
    };
    final updated = {for (final node in nodes) node.id: node};

    for (final row in rows) {
      final name = (row['name'] ?? '').trim().toLowerCase();
      if (name.isEmpty) continue;
      final existing = byName[name];
      if (existing == null) continue;
      final lat = double.tryParse((row['lat'] ?? '').trim());
      final lng = double.tryParse((row['lng'] ?? '').trim());
      final timezone = (row['timezone'] ?? '').trim();
      updated[existing.id] = LocationNode(
        id: existing.id,
        parentId: existing.parentId,
        level: existing.level,
        countryCode: existing.countryCode,
        name: existing.name,
        normalizedName: existing.normalizedName,
        timezone: timezone.isEmpty ? existing.timezone : timezone,
        latitude: lat ?? existing.latitude,
        longitude: lng ?? existing.longitude,
        metadata: existing.metadata,
        status: existing.status,
      );
    }
    return updated.values.toList(growable: false);
  }
}

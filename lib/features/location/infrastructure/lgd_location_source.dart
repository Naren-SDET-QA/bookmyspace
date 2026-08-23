import '../domain/india_location_source_validator.dart';
import '../domain/location_node.dart';

/// Local Government Directory rows → India administrative nodes.
/// Does not invent states, districts, or coordinates.
class LgdLocationSource {
  const LgdLocationSource();

  List<LocationNode> parse(List<Map<String, String>> rows) {
    final nodes = <String, LocationNode>{};
    void add(LocationNode node) => nodes.putIfAbsent(node.id, () => node);

    add(
      const LocationNode(
        id: 'in',
        level: LocationNodeLevel.country,
        countryCode: 'IN',
        name: 'India',
        normalizedName: 'india',
        timezone: 'Asia/Kolkata',
        status: 'active',
      ),
    );

    for (final row in rows) {
      if (!IndiaLocationSourceValidator.lgdRecord(row)) continue;
      final stateId = 'in-st-${row['state_code']!.trim()}';
      add(
        LocationNode(
          id: stateId,
          parentId: 'in',
          level: LocationNodeLevel.stateProvince,
          countryCode: 'IN',
          name: row['state_name']!.trim(),
          normalizedName: _norm(row['state_name']!),
          timezone: 'Asia/Kolkata',
          status: 'active',
        ),
      );

      final districtId = 'in-dt-${row['district_code']!.trim()}';
      add(
        LocationNode(
          id: districtId,
          parentId: stateId,
          level: LocationNodeLevel.districtCounty,
          countryCode: 'IN',
          name: row['district_name']!.trim(),
          normalizedName: _norm(row['district_name']!),
          timezone: 'Asia/Kolkata',
          status: 'active',
        ),
      );

      var adminParent = districtId;
      final subName = row['subdistrict_name']?.trim() ?? '';
      final subCode = row['subdistrict_code']?.trim() ?? '';
      if (subName.isNotEmpty && subCode.isNotEmpty) {
        adminParent = 'in-sd-$subCode';
        add(
          LocationNode(
            id: adminParent,
            parentId: districtId,
            level: LocationNodeLevel.mandalTalukTehsilBlock,
            countryCode: 'IN',
            name: subName,
            normalizedName: _norm(subName),
            timezone: 'Asia/Kolkata',
            status: 'active',
            metadata: {
              if ((row['subdistrict_type'] ?? '').trim().isNotEmpty)
                'administrative_type': row['subdistrict_type']!.trim(),
            },
          ),
        );
      }

      final townName = row['town_name']?.trim() ?? '';
      final townCode = row['town_code']?.trim() ?? '';
      if (townName.isNotEmpty && townCode.isNotEmpty) {
        add(
          LocationNode(
            id: 'in-tn-$townCode',
            parentId: adminParent,
            level: LocationNodeLevel.cityTown,
            countryCode: 'IN',
            name: townName,
            normalizedName: _norm(townName),
            timezone: 'Asia/Kolkata',
            status: 'active',
          ),
        );
      }

      final villageName = row['village_name']?.trim() ?? '';
      final villageCode = row['village_code']?.trim() ?? '';
      if (villageName.isNotEmpty && villageCode.isNotEmpty) {
        add(
          LocationNode(
            id: 'in-vl-$villageCode',
            parentId: adminParent,
            level: LocationNodeLevel.village,
            countryCode: 'IN',
            name: villageName,
            normalizedName: _norm(villageName),
            timezone: 'Asia/Kolkata',
            status: 'active',
          ),
        );
      }
    }
    return nodes.values.toList(growable: false);
  }

  static String _norm(String value) => value.trim().toLowerCase();
}

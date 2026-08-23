import 'india_location_source_validator.dart';
import 'location_node.dart';
import 'location_postal_code.dart';
import '../infrastructure/india_post_location_source.dart';
import '../infrastructure/lgd_location_source.dart';

class IndiaLocationImportResult {
  const IndiaLocationImportResult({
    required this.nodes,
    required this.pinLinks,
    this.sourcesMissing = false,
  });

  final List<LocationNode> nodes;
  final List<LocationPostalCode> pinLinks;
  final bool sourcesMissing;
}

/// Merges LGD hierarchy with India Post PIN rows. Unknown geography is dropped.
class IndiaLocationImporter {
  IndiaLocationImporter({
    this.lgdSource = const LgdLocationSource(),
    this.pinSource = const IndiaPostLocationSource(),
  });

  final LgdLocationSource lgdSource;
  final IndiaPostLocationSource pinSource;

  /// Official LGD / India Post files are not bundled. Dry-run must not invent rows.
  IndiaLocationImportResult dryRun() {
    return const IndiaLocationImportResult(
      nodes: [],
      pinLinks: [],
      sourcesMissing: true,
    );
  }

  IndiaLocationImportResult import({
    List<LocationNode> existingNodes = const [],
    required List<Map<String, String>> lgdRows,
    required List<Map<String, String>> pinRows,
  }) {
    final parsed = lgdSource.parse(lgdRows);
    final nodes = {
      for (final node in _preserveExisting(parsed, existingNodes))
        node.id: node,
    };
    final links = <String, LocationPostalCode>{};

    for (final mapping in pinSource.parse(pinRows)) {
      if (!IndiaLocationSourceValidator.pinRecord({
        'officename': mapping.locality,
        'pincode': mapping.postalCode,
        'districtname': mapping.district,
        'statename': mapping.state,
      })) {
        continue;
      }
      final parent = _resolveParent(
        nodes.values,
        state: mapping.state,
        district: mapping.district,
        taluk: mapping.taluk,
      );
      if (parent == null) continue;

      final localityId = 'in-lc-${parent.id}-${_norm(mapping.locality)}';
      final existing = nodes[localityId];
      final codes = {
        ...?existing?.postalCodes,
        mapping.postalCode,
      }.toList(growable: false);
      nodes[localityId] = LocationNode(
        id: localityId,
        parentId: parent.id,
        level: LocationNodeLevel.areaLocality,
        countryCode: 'IN',
        name: mapping.locality,
        normalizedName: _norm(mapping.locality),
        timezone: 'Asia/Kolkata',
        latitude: existing?.latitude ?? parent.latitude,
        longitude: existing?.longitude ?? parent.longitude,
        status: 'active',
        metadata: {'postal_codes': codes},
      );
      links['$localityId:${mapping.postalCode}'] = LocationPostalCode(
        locationId: localityId,
        postalCode: mapping.postalCode,
      );
    }

    return IndiaLocationImportResult(
      nodes: nodes.values.toList(growable: false),
      pinLinks: links.values.toList(growable: false),
    );
  }

  LocationNode? _resolveParent(
    Iterable<LocationNode> nodes, {
    required String state,
    required String district,
    String? taluk,
  }) {
    final stateNode = _named(nodes, LocationNodeLevel.stateProvince, state);
    if (stateNode == null) return null;
    final districtNode = _named(
      nodes.where((node) => node.parentId == stateNode.id),
      LocationNodeLevel.districtCounty,
      district,
    );
    if (districtNode == null) return null;

    LocationNode? mandal;
    if (taluk != null && taluk.trim().isNotEmpty) {
      mandal = _named(
        nodes.where((node) => node.parentId == districtNode.id),
        LocationNodeLevel.mandalTalukTehsilBlock,
        taluk,
      );
    }
    final adminParent = mandal ?? districtNode;
    LocationNode? under(String parentId, LocationNodeLevel level, String name) {
      return _named(
        nodes.where((node) => node.parentId == parentId),
        level,
        name,
      );
    }

    final town =
        under(adminParent.id, LocationNodeLevel.cityTown, district) ??
        under(districtNode.id, LocationNodeLevel.cityTown, district);
    final village =
        under(adminParent.id, LocationNodeLevel.village, district) ??
        under(districtNode.id, LocationNodeLevel.village, district);
    return town ?? village;
  }

  List<LocationNode> _preserveExisting(
    List<LocationNode> generated,
    List<LocationNode> existing,
  ) {
    if (existing.isEmpty) return generated;
    final generatedById = {for (final node in generated) node.id: node};
    final existingById = {for (final node in existing) node.id: node};
    String parentNameOf(LocationNode node, Map<String, LocationNode> byId) {
      if (node.parentId == null) return '';
      return byId[node.parentId]?.normalizedName ?? '';
    }

    String key(LocationNode node, String parentName) =>
        '${node.countryCode}|${node.level.name}|${node.normalizedName}|$parentName';

    final existingByKey = <String, LocationNode>{
      for (final node in existing)
        key(node, parentNameOf(node, existingById)): node,
    };

    final idMap = <String, String>{};
    final remapped = <String, LocationNode>{};
    final ordered = [...generated]
      ..sort((a, b) => a.level.index.compareTo(b.level.index));
    for (final node in ordered) {
      final parentName = parentNameOf(node, generatedById);
      final match = existingByKey[key(node, parentName)];
      final preservedId = match?.id ?? node.id;
      idMap[node.id] = preservedId;
      final preservedParentId = node.parentId == null
          ? null
          : idMap[node.parentId] ?? node.parentId;
      remapped[preservedId] = LocationNode(
        id: preservedId,
        parentId: preservedParentId,
        level: node.level,
        countryCode: node.countryCode,
        name: node.name,
        normalizedName: node.normalizedName,
        timezone: node.timezone ?? match?.timezone,
        latitude: node.latitude ?? match?.latitude,
        longitude: node.longitude ?? match?.longitude,
        metadata: node.metadata.isEmpty
            ? match?.metadata ?? const {}
            : node.metadata,
        status: node.status,
      );
    }
    return remapped.values.toList(growable: false);
  }

  LocationNode? _named(
    Iterable<LocationNode> nodes,
    LocationNodeLevel level,
    String name,
  ) {
    final needle = _norm(name);
    for (final node in nodes) {
      if (node.level == level && node.normalizedName == needle) return node;
    }
    return null;
  }

  static String _norm(String value) => value.trim().toLowerCase();
}

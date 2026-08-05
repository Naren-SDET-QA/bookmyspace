import 'package:dio/dio.dart';



import '../domain/venue_discovery.dart';

import '../domain/venue_discovery_provider.dart';

import '../domain/venue_import_geo_config.dart';



/// Compliant OSM Overpass discovery (public Overpass API only).

/// Category-aware: uses [VenueDiscoveryQuery.osmTags] or default category config.

class OsmVenueDiscoveryProvider implements VenueDiscoveryProvider {

  OsmVenueDiscoveryProvider({

    Dio? dio,

    this.overpassUrl = 'https://overpass-api.de/api/interpreter',

    this.limit = 25,

    this.bbox,

    this.userAgent = 'BookMySpace/1.0 (venue-import; compliant OSM fetch)',

  }) : _dio = dio ?? Dio();



  final Dio _dio;

  final String overpassUrl;

  final int limit;



  /// south,west,north,east — district batch when set (overrides query district lookup).

  final ImportBBox? bbox;

  final String userAgent;



  @override

  String get sourceCode => VenueDiscoverySources.osm;



  /// @Deprecated — use [kDefaultImportCategories] / geo config.

  static const defaultOsmTags = [

    'amenity=events_venue',

    'amenity=community_centre',

  ];



  /// @Deprecated — use [importDistrictConfig] / [kImportCountries].

  static final andhraDistrictBboxes = <String, ImportBBox>{

    for (final d in importStateConfig('India', 'Andhra Pradesh')?.districts ??

        const <ImportDistrictConfig>[])

      if (d.bbox != null) d.name: d.bbox!,

  };



  @override

  Future<List<VenueDiscoveryCandidate>> discover(VenueDiscoveryQuery query) async {

    final ql = buildOverpassQuery(query, bboxOverride: bbox, limit: limit);

    final response = await _dio.post<Map<String, dynamic>>(

      overpassUrl,

      data: ql,

      options: Options(

        contentType: 'application/x-www-form-urlencoded',

        headers: {'User-Agent': userAgent},

        responseType: ResponseType.json,

        sendTimeout: const Duration(seconds: 60),

        receiveTimeout: const Duration(seconds: 60),

      ),

    );



    final data = response.data ?? const <String, dynamic>{};

    final elements = (data['elements'] as List<dynamic>? ?? const [])

        .whereType<Map<String, dynamic>>()

        .map((e) => Map<String, dynamic>.from(e))

        .where((el) {

          final tagsMap = el['tags'];

          return tagsMap is Map && (tagsMap['name'] as String?)?.isNotEmpty == true;

        })

        .take(limit)

        .map((el) => _mapElement(el, query.categorySlug))

        .toList(growable: false);



    return elements;

  }



  /// Builds Overpass QL from country/state/district + category OSM tags.

  static String buildOverpassQuery(

    VenueDiscoveryQuery query, {

    ImportBBox? bboxOverride,

    int limit = 25,

  }) {

    final tags = resolveOsmTags(query);

    final filter = _tagFilters(tags);

    final area = resolveBBox(query, bboxOverride: bboxOverride);



    if (area != null) {

      final (s, w, n, e) = area;

      return '''

[out:json][timeout:60];

(

$filter

);

out center tags;

'''

          .replaceAllMapped(

            RegExp(r'\(area\.searchArea\)'),

            (_) => '($s,$w,$n,$e)',

          );

    }



    final district = query.district.trim();

    final useDistrict = district.isNotEmpty && district != kEntireState;



    if (useDistrict) {

      return '''

[out:json][timeout:60];

area["name"="${_esc(query.state)}"]["admin_level"~"4|5"]->.stateArea;

area["name"="${_esc(district)}"]["admin_level"~"5|6"](area.stateArea)->.searchArea;

(

$filter

);

out center tags;

''';

    }



    return '''

[out:json][timeout:60];

area["name"="${_esc(query.state)}"]["admin_level"~"4|5"]->.searchArea;

(

$filter

);

out center tags;

''';

  }



  static List<String> resolveOsmTags(VenueDiscoveryQuery query) {

    if (query.osmTags.isNotEmpty) return query.osmTags;

    final cfg = importCategoryBySlug(query.categorySlug);

    if (cfg != null && cfg.osmTags.isNotEmpty) return cfg.osmTags;

    return defaultOsmTags;

  }



  static ImportBBox? resolveBBox(

    VenueDiscoveryQuery query, {

    ImportBBox? bboxOverride,

  }) {

    if (bboxOverride != null) return bboxOverride;

    final district = query.district.trim();

    if (district.isEmpty || district == kEntireState) return null;

    return importDistrictConfig(query.country, query.state, district)?.bbox;

  }



  static String _tagFilters(List<String> osmTags) {

    final lines = <String>[];

    for (final raw in osmTags) {

      final tag = raw.trim();

      if (tag.isEmpty) continue;

      if (tag.startsWith('name~=')) {

        final pattern = tag.substring('name~='.length);

        lines.add('  nwr["name"~"${_esc(pattern)}",i](area.searchArea);');

      } else if (tag.contains('=')) {

        final i = tag.indexOf('=');

        final k = tag.substring(0, i);

        final v = tag.substring(i + 1);

        lines.add('  nwr["${_esc(k)}"="${_esc(v)}"](area.searchArea);');

      } else {

        lines.add('  nwr["${_esc(tag)}"](area.searchArea);');

      }

    }

    if (lines.isEmpty) {

      lines.add('  nwr["amenity"="events_venue"](area.searchArea);');

    }

    return lines.join('\n');

  }



  static String _esc(String value) =>

      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');



  VenueDiscoveryCandidate _mapElement(

    Map<String, dynamic> el,

    String categorySlug,

  ) {

    final tags = Map<String, dynamic>.from(el['tags'] as Map);

    final center = el['center'] as Map<String, dynamic>?;

    final lat = (el['lat'] as num?)?.toDouble() ??

        (center?['lat'] as num?)?.toDouble() ??

        0;

    final lon = (el['lon'] as num?)?.toDouble() ??

        (center?['lon'] as num?)?.toDouble() ??

        0;

    final osmId = '${el['type']}/${el['id']}';

    final name = '${tags['name']}'.trim();

    final fetchedAt = DateTime.now().toUtc();



    final amenities = <String>[];

    if (tags['wifi'] == 'yes') amenities.add('WiFi');

    if (tags['parking'] == 'yes') amenities.add('Parking');

    if (tags['toilets'] == 'yes') amenities.add('Restrooms');

    if (tags['air_conditioning'] == 'yes') amenities.add('Air conditioning');



    final imageRefs = <Map<String, dynamic>>[];

    if (tags['image'] != null) {

      imageRefs.add({'url': '${tags['image']}', 'alt': name});

    }

    if (tags['wikimedia_commons'] != null) {

      imageRefs.add({

        'url':

            'https://commons.wikimedia.org/wiki/Special:FilePath/${tags['wikimedia_commons']}',

        'alt': name,

      });

    }



    final street = [

      tags['addr:housenumber'],

      tags['addr:street'],

    ].where((e) => e != null && '$e'.isNotEmpty).join(' ');



    return VenueDiscoveryCandidate(

      name: name,

      categorySlug: categorySlug,

      latitude: lat,

      longitude: lon,

      addressLine1: street,

      city: '${tags['addr:city'] ?? tags['addr:town'] ?? ''}',

      district: '${tags['addr:district'] ?? tags['addr:suburb'] ?? ''}',

      state: '${tags['addr:state'] ?? ''}',

      country: '${tags['addr:country'] ?? 'IN'}',

      phone: '${tags['phone'] ?? tags['contact:phone'] ?? ''}',

      website: '${tags['website'] ?? tags['contact:website'] ?? ''}',

      amenities: amenities,

      imageRefs: imageRefs,

      provenance: VenueDiscoveryProvenance(

        sourceCode: VenueDiscoverySources.osm,

        sourcePlaceId: osmId,

        sourceUrl: 'https://www.openstreetmap.org/$osmId',

        fetchedAt: fetchedAt,

      ),

      raw: {'osm_tags': tags, 'hours': tags['opening_hours']},

    );

  }

}



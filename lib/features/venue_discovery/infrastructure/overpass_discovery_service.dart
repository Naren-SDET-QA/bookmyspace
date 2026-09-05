import 'package:dio/dio.dart';
import '../domain/venue_discovery.dart';

class OverpassDiscoveryService {
  OverpassDiscoveryService({
    Dio? client,
    this.endpoint = 'https://overpass-api.de/api/interpreter',
  }) : _client = client ?? Dio();
  final Dio _client;
  final String endpoint;

  Future<List<DiscoveredVenue>> discover({
    required String state,
    required String city,
    required String category,
    bool dryRun = true,
  }) async {
    if (state.trim().isEmpty || city.trim().isEmpty || category.trim().isEmpty)
      return const [];
    final query =
        '[out:json][timeout:25];area["name"="${_escape(state)}"]->.a;(nwr["name"](area.a)["amenity"~"${_escape(category)}",i];nwr["name"](area.a)["leisure"~"${_escape(category)}",i];);out center tags;';
    final response = await _client.post(
      endpoint,
      data: {'data': query},
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final parsed = OverpassVenueParser.parse(
      Map<String, dynamic>.from(response.data as Map),
      sourceUrl: endpoint,
      category: category,
    );
    return parsed
        .where(
          (v) =>
              (v.city ?? '').toLowerCase().contains(city.toLowerCase()) ||
              v.rawMetadata['addr:city'] == null,
        )
        .toList(growable: false);
  }

  String _escape(String value) =>
      value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
}

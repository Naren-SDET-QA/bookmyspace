import '../domain/venue_discovery.dart';
import '../domain/venue_discovery_provider.dart';

/// Phase 3 stub: no network, no staging — returns an empty candidate list.
///
/// Replace with OSM/Google implementations in a later phase.
class NoopVenueDiscoveryProvider implements VenueDiscoveryProvider {
  const NoopVenueDiscoveryProvider({
    this.sourceCode = VenueDiscoverySources.osm,
  });

  @override
  final String sourceCode;

  @override
  Future<List<VenueDiscoveryCandidate>> discover(VenueDiscoveryQuery query) async {
    return const [];
  }
}

/// In-memory provider for tests / dry-run previews (no persistence).
class MemoryVenueDiscoveryProvider implements VenueDiscoveryProvider {
  MemoryVenueDiscoveryProvider({
    this.sourceCode = VenueDiscoverySources.osm,
    List<VenueDiscoveryCandidate>? seed,
  }) : _seed = List.unmodifiable(seed ?? const []);

  @override
  final String sourceCode;

  final List<VenueDiscoveryCandidate> _seed;

  @override
  Future<List<VenueDiscoveryCandidate>> discover(VenueDiscoveryQuery query) async {
    return _seed
        .where(
          (c) =>
              c.categorySlug == query.categorySlug ||
              c.categorySlug.isEmpty,
        )
        .toList(growable: false);
  }
}

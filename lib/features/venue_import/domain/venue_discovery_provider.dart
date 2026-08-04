import 'venue_discovery.dart';

/// Pluggable venue discovery provider (OSM / Google / manual).
///
/// Phase 3: interface + dry-run only — implementations must not bulk-stage
/// or publish venues. Live network fetch is optional and out of scope here.
abstract class VenueDiscoveryProvider {
  /// Stable source code matching `venue_sources.code`.
  String get sourceCode;

  /// Discover candidates for [query]. Must not write to staging/import tables.
  Future<List<VenueDiscoveryCandidate>> discover(VenueDiscoveryQuery query);
}

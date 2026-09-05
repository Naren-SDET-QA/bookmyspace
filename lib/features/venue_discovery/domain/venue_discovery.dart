enum StageStatus { staged, duplicate, invalid }

enum ReviewStatus { approved, rejected, invalidTransition, notFound }

enum ClaimStatus { claimed, alreadyClaimed, ineligible, notFound }

class DiscoveredVenue {
  const DiscoveredVenue({
    required this.source,
    required this.sourcePlaceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    this.phone,
    this.website,
    this.openingHours,
    this.category,
    this.sourceUrl,
    this.rawMetadata = const {},
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? null;
  final String source, sourcePlaceId, name;
  final double latitude, longitude;
  final String? address,
      city,
      state,
      phone,
      website,
      openingHours,
      category,
      sourceUrl;
  final Map<String, dynamic> rawMetadata;
  final DateTime? discoveredAt;
}

class AuditEntry {
  const AuditEntry(this.sourcePlaceId, this.action, this.actorId);
  final String sourcePlaceId, action, actorId;
}

class InMemoryVenueStagingStore {
  final Map<String, DiscoveredVenue> _records = {};
  final Map<String, String> _status = {};
  final Map<String, String> _claims = {};
  final List<AuditEntry> audit = [];
  List<DiscoveredVenue> get records => _records.values.toList(growable: false);
  StageStatus stage(DiscoveredVenue venue) {
    if (venue.source.trim().isEmpty || venue.sourcePlaceId.trim().isEmpty)
      return StageStatus.invalid;
    final key = '${venue.source}:${venue.sourcePlaceId}';
    if (_records.containsKey(key)) return StageStatus.duplicate;
    _records[key] = venue;
    _status[key] = 'pending_review';
    return StageStatus.staged;
  }

  ReviewStatus review(
    String id, {
    required bool approved,
    required String actorId,
  }) {
    final key = 'osm:$id';
    if (!_records.containsKey(key)) return ReviewStatus.notFound;
    if (_status[key] != 'pending_review') return ReviewStatus.invalidTransition;
    _status[key] = approved ? 'approved' : 'rejected';
    audit.add(AuditEntry(id, approved ? 'approve' : 'reject', actorId));
    return approved ? ReviewStatus.approved : ReviewStatus.rejected;
  }

  bool publish(String id, {required String actorId}) {
    final key = 'osm:$id';
    if (_status[key] != 'approved') return false;
    _status[key] = 'published';
    audit.add(AuditEntry(id, 'publish', actorId));
    return true;
  }

  ClaimStatus claim(String id, String ownerId) {
    final key = 'osm:$id';
    if (!_records.containsKey(key)) return ClaimStatus.notFound;
    if (_status[key] != 'published') return ClaimStatus.ineligible;
    if (_claims.containsKey(key)) return ClaimStatus.alreadyClaimed;
    _claims[key] = ownerId;
    audit.add(AuditEntry(id, 'claim', ownerId));
    return ClaimStatus.claimed;
  }
}

class OverpassVenueParser {
  static List<DiscoveredVenue> parse(
    Map<String, dynamic> payload, {
    String? sourceUrl,
    String category = 'venue',
  }) {
    final elements = payload['elements'];
    if (elements is! List) return const [];
    return elements
        .whereType<Map>()
        .map((e) {
          final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? {};
          final type = e['type']?.toString() ?? 'element';
          final id = e['id']?.toString();
          final lat =
              (e['lat'] as num?)?.toDouble() ??
              (e['center']?['lat'] as num?)?.toDouble();
          final lon =
              (e['lon'] as num?)?.toDouble() ??
              (e['center']?['lon'] as num?)?.toDouble();
          if (id == null ||
              lat == null ||
              lon == null ||
              (tags['name']?.toString().trim().isEmpty ?? true))
            return null;
          return DiscoveredVenue(
            source: 'osm',
            sourcePlaceId: '$type/$id',
            name: tags['name'].toString(),
            latitude: lat,
            longitude: lon,
            address: tags['addr:full']?.toString(),
            city: tags['addr:city']?.toString(),
            state: tags['addr:state']?.toString(),
            phone: tags['phone']?.toString(),
            website: tags['website']?.toString(),
            openingHours: tags['opening_hours']?.toString(),
            category: category,
            sourceUrl: sourceUrl,
            rawMetadata: Map<String, dynamic>.from(tags),
            discoveredAt: DateTime.now(),
          );
        })
        .whereType<DiscoveredVenue>()
        .toList(growable: false);
  }
}

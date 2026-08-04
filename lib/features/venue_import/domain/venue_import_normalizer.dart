/// Normalization and deduplication utilities for venue import data.

/// Normalizes phone numbers to E.164 when possible (India +91 default).
String? normalizeVenuePhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;

  final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.startsWith('+91') && cleaned.length == 13) return cleaned;

  final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length == 10) return '+91$digitsOnly';
  if (cleaned.startsWith('+')) return cleaned;
  return cleaned.isEmpty ? null : cleaned;
}

/// Collapses whitespace and trims address strings.
String? normalizeVenueAddress(String? address) {
  if (address == null) return null;
  final normalized = address.trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.isEmpty ? null : normalized;
}

/// Normalized key for name+location deduplication (~100m grid).
String dedupeKey({
  required String name,
  required double latitude,
  required double longitude,
}) {
  final normalizedName = name.trim().toLowerCase();
  final latKey = (latitude * 1000).round();
  final lngKey = (longitude * 1000).round();
  return '$normalizedName|$latKey|$lngKey';
}

/// Returns true when two venues are likely duplicates.
bool isLikelyDuplicate({
  required String nameA,
  required double latA,
  required double lngA,
  required String nameB,
  required double latB,
  required double lngB,
  String? placeIdA,
  String? placeIdB,
}) {
  if (placeIdA != null &&
      placeIdB != null &&
      placeIdA.isNotEmpty &&
      placeIdA == placeIdB) {
    return true;
  }
  return dedupeKey(name: nameA, latitude: latA, longitude: lngA) ==
      dedupeKey(name: nameB, latitude: latB, longitude: lngB);
}

/// Fields protected from import overwrite when owner-verified.
const ownerVerifiableFields = [
  'name',
  'category_id',
  'address_line1',
  'city',
  'state',
  'postal_code',
  'latitude',
  'longitude',
  'phone',
  'website',
  'description',
  'capacity',
  'pricing_base_amount',
];

/// Merges import data into existing venue map, skipping owner-verified fields.
Map<String, dynamic> mergeImportRespectingOwnerVerified({
  required Map<String, dynamic> existing,
  required Map<String, dynamic> imported,
  required List<String> ownerVerifiedFields,
}) {
  final result = Map<String, dynamic>.from(existing);
  for (final entry in imported.entries) {
    if (!ownerVerifiedFields.contains(entry.key)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}

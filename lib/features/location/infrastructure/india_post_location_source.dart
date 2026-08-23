import '../domain/india_location_source_validator.dart';
import '../domain/india_pin.dart';

class IndiaPostPinMapping {
  const IndiaPostPinMapping({
    required this.postalCode,
    required this.locality,
    required this.district,
    required this.state,
    this.taluk,
  });

  final String postalCode;
  final String locality;
  final String district;
  final String state;
  final String? taluk;
}

/// India Post PIN-directory rows. One PIN may yield many office/localities.
class IndiaPostLocationSource {
  const IndiaPostLocationSource();

  List<IndiaPostPinMapping> parse(List<Map<String, String>> rows) {
    final mappings = <IndiaPostPinMapping>[];
    for (final row in rows) {
      if (!IndiaLocationSourceValidator.pinRecord(row)) continue;
      mappings.add(
        IndiaPostPinMapping(
          postalCode: IndiaPin.normalize(row['pincode']!)!,
          locality: row['officename']!.trim(),
          district: row['districtname']!.trim(),
          state: row['statename']!.trim(),
          taluk: (row['taluk'] ?? '').trim().isEmpty
              ? null
              : row['taluk']!.trim(),
        ),
      );
    }
    return List.unmodifiable(mappings);
  }
}

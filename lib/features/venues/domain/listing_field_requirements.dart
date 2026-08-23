import 'category_configuration.dart';

/// Known owner-listing field keys stored in category metadata.
///
/// Admin listing-fields config is metadata-driven. Unknown keys never invent
/// columns; they are shown as hints and only known keys are validated.
class ListingFieldRequirements {
  const ListingFieldRequirements({
    required this.requiredKeys,
    required this.optionalKeys,
    required this.ownerKeys,
  });

  final List<String> requiredKeys;
  final List<String> optionalKeys;
  final List<String> ownerKeys;

  static const defaultRequired = [
    'name',
    'city',
    'location',
    'capacity',
    'price',
  ];

  static const defaultOptional = [
    'description',
    'address',
    'photos',
    'amenities',
  ];

  factory ListingFieldRequirements.from(CategoryConfiguration? config) {
    final required = _clean(config?.requiredFields ?? const []);
    final optional = _clean(config?.optionalFields ?? const []);
    final owner = _clean(config?.ownerFields ?? const []);
    return ListingFieldRequirements(
      requiredKeys: required.isEmpty ? defaultRequired : required,
      optionalKeys: optional.isEmpty && required.isEmpty
          ? defaultOptional
          : optional,
      ownerKeys: owner,
    );
  }

  bool isRequired(String key) =>
      requiredKeys.any((item) => _normalize(item) == _normalize(key));

  /// Returns configured required keys that are empty on the current draft.
  List<String> missing({
    required String name,
    required String city,
    required String description,
    required String address,
    required String? locationId,
    required int? capacity,
    required double? price,
    required int photoCount,
    required int amenityCount,
  }) {
    final absent = <String>[];
    for (final key in requiredKeys) {
      final empty = switch (_normalize(key)) {
        'name' || 'title' => name.trim().isEmpty,
        'city' => city.trim().isEmpty,
        'description' => description.trim().isEmpty,
        'address' || 'address_line1' => address.trim().isEmpty,
        'location' ||
        'location_node' ||
        'location_node_id' => locationId == null || locationId.isEmpty,
        'capacity' ||
        'guest_count' ||
        'seats' => capacity == null || capacity <= 0,
        'price' ||
        'pricing' ||
        'pricing_base_amount' ||
        'fee' => price == null || price <= 0,
        'photos' || 'images' => photoCount <= 0,
        'amenities' || 'facilities' => amenityCount <= 0,
        _ => false,
      };
      if (empty) absent.add(key);
    }
    return absent;
  }

  static List<String> _clean(List<String> raw) => raw
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  static String _normalize(String key) =>
      key.trim().toLowerCase().replaceAll(' ', '_');
}

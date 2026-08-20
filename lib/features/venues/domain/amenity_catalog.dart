class AmenityDefinition {
  const AmenityDefinition(this.id, this.label, {this.sections = const {}});
  final String id;
  final String label;
  final Set<String> sections;
}

/// One normalized amenity vocabulary shared by every listing section.
abstract final class AmenityCatalog {
  static const all = <AmenityDefinition>[
    AmenityDefinition('wifi', 'Wi-Fi'),
    AmenityDefinition('parking', 'Parking'),
    AmenityDefinition('ac', 'AC'),
    AmenityDefinition('power_backup', 'Power backup'),
    AmenityDefinition('kitchen', 'Kitchen'),
    AmenityDefinition('cctv', 'CCTV'),
    AmenityDefinition('security', 'Security'),
    AmenityDefinition('generator', 'Generator'),
    AmenityDefinition('pool', 'Swimming pool'),
    AmenityDefinition('gym', 'Gym'),
    AmenityDefinition('projector', 'Projector'),
    AmenityDefinition('catering', 'Food/catering'),
    AmenityDefinition('bathroom', 'Attached bathroom'),
    AmenityDefinition('laundry', 'Laundry'),
    AmenityDefinition('furnished', 'Furnished'),
    AmenityDefinition('sports_equipment', 'Sports equipment'),
  ];
  static AmenityDefinition? byId(String id) {
    for (final amenity in all) {
      if (amenity.id == id) return amenity;
    }
    return null;
  }
}

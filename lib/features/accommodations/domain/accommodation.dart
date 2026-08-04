enum AccommodationModule { pg, stay }

class AccommodationQuery {
  const AccommodationQuery({required this.module, this.search = '', this.type});

  final AccommodationModule module;
  final String search;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is AccommodationQuery &&
      other.module == module &&
      other.search == search &&
      other.type == type;

  @override
  int get hashCode => Object.hash(module, search, type);
}

class AccommodationProperty {
  const AccommodationProperty({
    required this.id,
    required this.module,
    required this.propertyType,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.amenities,
    required this.foodIncluded,
    required this.units,
    this.genderPolicy,
    this.coverImage = '',
    this.photos = const [],
    this.checkInTime = '14:00',
    this.checkOutTime = '11:00',
    this.bookingMode = 'instant',
    this.rules = const {},
    this.registrationFormId,
  });

  final String id;
  final AccommodationModule module;
  final String propertyType;
  final String? genderPolicy;
  final String name;
  final String description;
  final String address;
  final String city;
  final String coverImage;
  final List<String> photos;
  final String checkInTime, checkOutTime, bookingMode;
  final Map<String, dynamic> rules;
  final String? registrationFormId;
  final List<String> amenities;
  final bool foodIncluded;
  final List<AccommodationUnit> units;

  bool get hasAvailability => units.any((unit) => unit.inventory > 0);
  double get startingPrice => units.isEmpty
      ? 0
      : units.map((unit) => unit.price).reduce((a, b) => a < b ? a : b);

  factory AccommodationProperty.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['accommodation_units'] as List<dynamic>? ?? const [];
    return AccommodationProperty(
      id: json['id'] as String? ?? '',
      module: json['module'] == 'pg'
          ? AccommodationModule.pg
          : AccommodationModule.stay,
      propertyType: json['property_type'] as String? ?? '',
      genderPolicy: json['gender_policy'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      checkInTime: json['check_in_time']?.toString() ?? '14:00',
      checkOutTime: json['check_out_time']?.toString() ?? '11:00',
      bookingMode: json['booking_mode'] as String? ?? 'instant',
      rules: Map<String, dynamic>.from(json['stay_rules'] as Map? ?? const {}),
      registrationFormId: json['registration_form_id'] as String?,
      amenities: (json['amenities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      foodIncluded: json['food_included'] as bool? ?? false,
      units: rawUnits
          .whereType<Map<String, dynamic>>()
          .map(AccommodationUnit.fromJson)
          .toList(),
    );
  }
}

class AccommodationUnit {
  const AccommodationUnit({
    required this.id,
    required this.name,
    required this.occupancyType,
    required this.capacity,
    required this.inventory,
    required this.rentMonthly,
    required this.priceNightly,
    required this.deposit,
    required this.availableFrom,
    required this.amenities,
    this.photos = const [],
  });

  final String id;
  final String name;
  final String occupancyType;
  final int capacity;
  final int inventory;
  final double? rentMonthly;
  final double? priceNightly;
  final double deposit;
  final DateTime availableFrom;
  final List<String> amenities;
  final List<String> photos;

  String? get primaryPhoto => photos.isNotEmpty ? photos.first : null;

  double get price => rentMonthly ?? priceNightly ?? 0;

  factory AccommodationUnit.fromJson(Map<String, dynamic> json) =>
      AccommodationUnit(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        occupancyType: json['occupancy_type'] as String? ?? '',
        capacity: (json['capacity'] as num?)?.toInt() ?? 1,
        inventory: (json['inventory'] as num?)?.toInt() ?? 0,
        rentMonthly: (json['rent_monthly'] as num?)?.toDouble(),
        priceNightly: (json['price_nightly'] as num?)?.toDouble(),
        deposit: (json['deposit'] as num?)?.toDouble() ?? 0,
        availableFrom:
            DateTime.tryParse(json['available_from'] as String? ?? '') ??
            DateTime.now(),
        amenities: (json['amenities'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
}

class AccommodationReservationRequest {
  const AccommodationReservationRequest({
    required this.propertyId,
    required this.unitId,
    this.moveIn,
    this.checkIn,
    this.checkOut,
    this.guests = 1,
    this.children = 0,
    this.rooms = const [],
    required this.idempotencyKey,
    this.registrationSubmissionId,
  });

  final String propertyId;
  final String unitId;
  final DateTime? moveIn;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;
  final int children;
  final List<StayRoomSelection> rooms;
  final String idempotencyKey;
  final String? registrationSubmissionId;
}

class StayRoomSelection {
  const StayRoomSelection(this.unitId, this.quantity);
  final String unitId;
  final int quantity;
  Map<String, dynamic> toJson() => {'unit_id': unitId, 'quantity': quantity};
}

class StayUnitAvailability {
  const StayUnitAvailability({
    required this.unitId,
    required this.available,
    required this.nightlyRate,
  });
  final String unitId;
  final int available;
  final double nightlyRate;
  factory StayUnitAvailability.fromJson(Map<String, dynamic> json) =>
      StayUnitAvailability(
        unitId: json['unit_id'] as String,
        available: (json['available'] as num).toInt(),
        nightlyRate: (json['nightly_rate'] as num).toDouble(),
      );
}

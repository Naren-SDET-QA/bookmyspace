class RoomReservation {
  const RoomReservation({
    required this.checkIn,
    required this.checkOut,
    required this.quantity,
  });

  final String checkIn;
  final String checkOut;
  final int quantity;
}

class RoomInventory {
  const RoomInventory({
    required this.id,
    required this.roomTypeId,
    required this.name,
    required this.quantity,
    required this.capacity,
    required this.bedType,
    required this.amenities,
  });

  final String id;
  final String roomTypeId;
  final String name;
  final int quantity;
  final int capacity;
  final String bedType;
  final List<String> amenities;

  bool canReserve({
    required DateTime checkIn,
    required DateTime checkOut,
    required List<RoomReservation> reservations,
    int quantity = 1,
  }) {
    if (quantity < 1 || checkOut.isAfter(checkIn) == false) return false;
    final used = reservations.where((reservation) {
      final start = DateTime.parse(reservation.checkIn);
      final end = DateTime.parse(reservation.checkOut);
      return checkIn.isBefore(end) && checkOut.isAfter(start);
    }).fold<int>(0, (total, reservation) => total + reservation.quantity);
    return used + quantity <= this.quantity;
  }
}

class HotelRoomType {
  const HotelRoomType({
    required this.id,
    required this.venueId,
    required this.name,
    required this.description,
    required this.capacity,
    required this.bedType,
    required this.amenities,
    required this.images,
  });

  final String id;
  final String venueId;
  final String name;
  final String description;
  final int capacity;
  final String bedType;
  final List<String> amenities;
  final List<String> images;

  factory HotelRoomType.fromJson(Map<String, dynamic> json) {
    final amenities = json['amenities'];
    final imageRows = json['hotel_room_images'];
    return HotelRoomType(
      id: json['id'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      bedType: json['bed_type'] as String? ?? '',
      amenities: amenities is List
          ? amenities.map((e) => e.toString()).toList()
          : const [],
      images: imageRows is List
          ? imageRows
                .whereType<Map>()
                .map((e) => e['url']?.toString() ?? '')
                .where((e) => e.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

import '../../booking/domain/booking.dart';

enum MeetingRoomType { meeting, conference, training }

class MeetingRoom {
  const MeetingRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.hourlyRate,
    required this.halfDayRate,
    required this.fullDayRate,
    required this.bufferMinutes,
    required this.bookingMode,
    this.city = '',
    this.description = '',
    this.amenities = const [],
  });

  final String id;
  final String name;
  final MeetingRoomType type;
  final int capacity;
  final double hourlyRate;
  final double halfDayRate;
  final double fullDayRate;
  final int bufferMinutes;
  final String bookingMode;
  final String city;
  final String description;
  final List<String> amenities;

  factory MeetingRoom.fromJson(Map<String, dynamic> json) {
    final venue = Map<String, dynamic>.from(json['venues'] as Map? ?? const {});
    return MeetingRoom(
      id: json['venue_id'] as String? ?? venue['id'] as String? ?? '',
      name: venue['name'] as String? ?? '',
      type: MeetingRoomType.values.firstWhere(
        (value) => value.name == json['room_type'],
        orElse: () => MeetingRoomType.meeting,
      ),
      capacity: (venue['capacity'] as num?)?.toInt() ?? 0,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      halfDayRate: (json['half_day_rate'] as num?)?.toDouble() ?? 0,
      fullDayRate: (json['full_day_rate'] as num?)?.toDouble() ?? 0,
      bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
      bookingMode: json['booking_mode'] as String? ?? 'instant',
      city: venue['city'] as String? ?? '',
      description: venue['description'] as String? ?? '',
      amenities:
          (json['amenities'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

class MeetingRoomQuote {
  const MeetingRoomQuote({
    required this.available,
    required this.price,
    this.endTime = '',
    this.reason = '',
  });
  final bool available;
  final double price;
  final String endTime;
  final String reason;

  factory MeetingRoomQuote.fromJson(Map<String, dynamic> json) =>
      MeetingRoomQuote(
        available: json['available'] as bool? ?? false,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        endTime: json['end_time']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
      );
}

abstract interface class MeetingRoomRepository {
  Future<List<MeetingRoom>> rooms();
  Future<List<MeetingRoom>> ownedRooms();
  Future<MeetingRoom> room(String id);
  Future<MeetingRoomQuote> quote(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
  );
  Future<List<Booking>> book(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
    List<DateTime> recurrenceDates,
  );
  Future<String> createRoom({
    required String name,
    required String description,
    required String city,
    required String state,
    required int capacity,
    required MeetingRoomType type,
    required double hourlyRate,
    required double halfDayRate,
    required double fullDayRate,
    required int bufferMinutes,
    required List<String> amenities,
  });
  Future<String> offlineBooking(
    String roomId,
    DateTime date,
    String startTime,
    int durationMinutes,
    String customerName,
    String customerPhone,
  );
  Future<void> addBreak(
    String roomId,
    int dayOfWeek,
    String startTime,
    String endTime,
    String label,
  );
  Future<void> setWorkingHours(
    String roomId,
    int dayOfWeek,
    String opensAt,
    String closesAt, {
    bool closed = false,
  });
  Future<void> setBookingMode(String roomId, String mode);
}

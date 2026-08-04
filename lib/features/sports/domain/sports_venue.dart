import '../../booking/domain/booking.dart';

enum SportType { cricket, football, badminton, tennis, turf, indoor }

class SportsVenue {
  const SportsVenue({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.hourlyRate,
    required this.sessionMinutes,
    required this.sessionRate,
    required this.bufferMinutes,
    required this.bookingMode,
    this.city = '',
    this.description = '',
    this.equipment = const [],
    this.amenities = const [],
  });
  final String id, name, city, description, bookingMode;
  final SportType type;
  final int capacity, sessionMinutes, bufferMinutes;
  final double hourlyRate, sessionRate;
  final List<String> equipment, amenities;
  factory SportsVenue.fromJson(Map<String, dynamic> json) {
    final v = Map<String, dynamic>.from(json['venues'] as Map? ?? const {});
    return SportsVenue(
      id: json['venue_id'] as String? ?? '',
      name: v['name'] as String? ?? '',
      type: SportType.values.firstWhere(
        (e) => e.name == json['sport_type'],
        orElse: () => SportType.indoor,
      ),
      capacity: (v['capacity'] as num?)?.toInt() ?? 0,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      sessionMinutes: (json['session_minutes'] as num?)?.toInt() ?? 60,
      sessionRate: (json['session_rate'] as num?)?.toDouble() ?? 0,
      bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
      bookingMode: json['booking_mode'] as String? ?? 'instant',
      city: v['city'] as String? ?? '',
      description: v['description'] as String? ?? '',
      equipment:
          (json['equipment'] as List?)?.map((e) => '$e').toList() ?? const [],
      amenities:
          (json['amenities'] as List?)?.map((e) => '$e').toList() ?? const [],
    );
  }
}

class SportsQuote {
  const SportsQuote({
    required this.available,
    required this.price,
    this.endTime = '',
    this.reason = '',
  });
  final bool available;
  final double price;
  final String endTime, reason;
  factory SportsQuote.fromJson(Map<String, dynamic> j) => SportsQuote(
    available: j['available'] as bool? ?? false,
    price: (j['price'] as num?)?.toDouble() ?? 0,
    endTime: j['end_time']?.toString() ?? '',
    reason: j['reason']?.toString() ?? '',
  );
}

abstract interface class SportsRepository {
  Future<List<SportsVenue>> venues({bool owned = false});
  Future<SportsVenue> venue(String id);
  Future<SportsQuote> quote(
    String id,
    DateTime date,
    String start,
    int duration,
  );
  Future<List<Booking>> book(
    String id,
    DateTime date,
    String start,
    int duration,
    List<DateTime> recurrence,
  );
  Future<String> create({
    required String name,
    required String city,
    required int capacity,
    required SportType type,
    required double hourlyRate,
    required int sessionMinutes,
    required double sessionRate,
    required int bufferMinutes,
  });
  Future<String> offline(String id, DateTime date, String start, int duration);
  Future<void> setMode(String id, String mode);
  Future<void> addBreak(String id, int day, String start, String end);
}

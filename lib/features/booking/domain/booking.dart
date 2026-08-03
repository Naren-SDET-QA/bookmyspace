/// A bookable time slot for a venue (`time_slots`).
class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.venueId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    this.isActive = true,
  });

  final String id;
  final String venueId;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isActive;

  /// "09:00:00" -> "09:00" for display.
  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;

  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    id: json['id'] as String? ?? '',
    venueId: json['venue_id'] as String? ?? '',
    label: json['label'] as String? ?? '',
    startTime: json['start_time'] as String? ?? '',
    endTime: json['end_time'] as String? ?? '',
    priceAmount: (json['price_amount'] as num?)?.toDouble() ?? 0,
    isActive: json['is_active'] as bool? ?? true,
  );
}

/// Availability of a single slot, returned by `available_time_slots`.
class SlotAvailability {
  const SlotAvailability({
    required this.slotId,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    required this.isAvailable,
    required this.reason,
  });

  final String slotId;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isAvailable;
  final String reason;

  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory SlotAvailability.fromJson(Map<String, dynamic> json) =>
      SlotAvailability(
        slotId: json['slot_id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        priceAmount: (json['price_amount'] as num?)?.toDouble() ?? 0,
        isAvailable: json['is_available'] as bool? ?? false,
        reason: json['reason'] as String? ?? 'unavailable',
      );
}

/// Lifecycle status of a booking (`booking_status` enum).
enum BookingStatus {
  held,
  pending,
  confirmed,
  completed,
  cancelled,
  refunded,
  noShow;

  static BookingStatus fromDb(String value) => switch (value) {
    'held' => BookingStatus.held,
    'pending' => BookingStatus.pending,
    'confirmed' => BookingStatus.confirmed,
    'completed' => BookingStatus.completed,
    'cancelled' => BookingStatus.cancelled,
    'refunded' => BookingStatus.refunded,
    'no_show' => BookingStatus.noShow,
    _ => BookingStatus.pending,
  };

  String get dbValue => switch (this) {
    BookingStatus.held => 'held',
    BookingStatus.pending => 'pending',
    BookingStatus.confirmed => 'confirmed',
    BookingStatus.completed => 'completed',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.refunded => 'refunded',
    BookingStatus.noShow => 'no_show',
  };
}

/// A booking made by the user.
class Booking {
  const Booking({
    required this.id,
    required this.bookingRef,
    required this.venueId,
    required this.slotId,
    required this.bookDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    this.venueName = '',
    this.venueCity = '',
    this.slotLabel = '',
    this.createdAt,
  });

  final String id;
  final String bookingRef;
  final String venueId;
  final String slotId;
  final DateTime bookDate;
  final String startTime;
  final String endTime;
  final BookingStatus status;
  final double amount;
  final double taxAmount;
  final double totalAmount;

  /// Hydrated venue display fields (empty when not joined).
  final String venueName;
  final String venueCity;
  final String slotLabel;
  final DateTime? createdAt;

  bool get isActive =>
      status == BookingStatus.pending ||
      status == BookingStatus.confirmed ||
      status == BookingStatus.held;

  bool get canCancel => status == BookingStatus.pending;

  /// Confirmed (captured) bookings can be refunded.
  bool get canRefund => status == BookingStatus.confirmed;

  String get displayStart =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get displayEnd =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final venueRaw = json['venues'];
    final slotRaw = json['time_slots'];
    return Booking(
      id: json['id'] as String? ?? '',
      bookingRef: json['booking_ref'] as String? ?? '',
      venueId: json['venue_id'] as String? ?? '',
      slotId: json['slot_id'] as String? ?? '',
      bookDate:
          DateTime.tryParse(json['book_date'] as String? ?? '') ??
          DateTime(1970),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: BookingStatus.fromDb(json['status'] as String? ?? 'pending'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      venueName: venueRaw is Map<String, dynamic>
          ? (venueRaw['name'] as String? ?? '')
          : '',
      venueCity: venueRaw is Map<String, dynamic>
          ? (venueRaw['city'] as String? ?? '')
          : '',
      slotLabel: slotRaw is Map<String, dynamic>
          ? (slotRaw['label'] as String? ?? '')
          : '',
    );
  }
}

/// Result of a successfully acquired booking hold.
class BookingHold {
  const BookingHold({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;

  factory BookingHold.fromResponse(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in_minutes'] as num?)?.toInt() ?? 10;
    return BookingHold(
      id: json['hold_id'] as String? ?? '',
      expiresAt: DateTime.now().add(Duration(minutes: expiresIn)),
    );
  }
}

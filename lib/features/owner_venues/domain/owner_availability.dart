class OwnerOperatingHours {
  const OwnerOperatingHours({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
    this.id,
  });
  final String? id;
  final int dayOfWeek;
  final String opensAt;
  final String closesAt;
  final bool isClosed;
  Map<String, dynamic> toJson(String venueId) => {
    'id': id,
    'venue_id': venueId,
    'day_of_week': dayOfWeek,
    'opens_at': opensAt,
    'closes_at': closesAt,
    'is_closed': isClosed,
  };
  factory OwnerOperatingHours.fromJson(Map<String, dynamic> row) =>
      OwnerOperatingHours(
        id: row['id'] as String?,
        dayOfWeek: (row['day_of_week'] as num).toInt(),
        opensAt: row['opens_at'] as String? ?? '09:00:00',
        closesAt: row['closes_at'] as String? ?? '18:00:00',
        isClosed: row['is_closed'] as bool? ?? false,
      );
}

class OwnerTimeSlot {
  const OwnerTimeSlot({
    required this.id,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.priceAmount,
    this.isActive = true,
  });
  final String? id;
  final String label;
  final String startTime;
  final String endTime;
  final double priceAmount;
  final bool isActive;
  static void validate({
    required String label,
    required String startTime,
    required String endTime,
    required double priceAmount,
  }) {
    if (label.trim().isEmpty) throw StateError('Slot name is required.');
    final start = _minutes(startTime);
    final end = _minutes(endTime);
    if (start == null || end == null || start >= end) {
      throw StateError('Start time must be before end time.');
    }
    if (priceAmount < 0) throw StateError('Price cannot be negative.');
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  factory OwnerTimeSlot.fromJson(Map<String, dynamic> row) => OwnerTimeSlot(
    id: row['id'] as String?,
    label: row['label'] as String? ?? '',
    startTime: row['start_time'] as String? ?? '09:00:00',
    endTime: row['end_time'] as String? ?? '10:00:00',
    priceAmount: (row['price_amount'] as num?)?.toDouble() ?? 0,
    isActive: row['is_active'] as bool? ?? true,
  );
}

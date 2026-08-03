/// Event categories (`event_category` enum).
enum EventCategory {
  meeting,
  conference,
  workshop,
  sports,
  entertainment,
  cultural,
  exhibition,
  community;

  static EventCategory fromDb(String value) => switch (value) {
    'meeting' => EventCategory.meeting,
    'conference' => EventCategory.conference,
    'workshop' => EventCategory.workshop,
    'sports' => EventCategory.sports,
    'entertainment' => EventCategory.entertainment,
    'cultural' => EventCategory.cultural,
    'exhibition' => EventCategory.exhibition,
    'community' => EventCategory.community,
    _ => EventCategory.community,
  };

  String get dbValue => name;
}

/// An event published by an organisation (`events`).
class Event {
  const Event({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.category,
    required this.isFree,
    this.venueId = '',
    this.venueName = '',
    this.capacity = 0,
    this.ticketPrice = 0,
    this.coverImage = '',
    this.status = 'published',
    this.registeredCount = 0,
    this.userRegistered = false,
  });

  final String id;
  final String orgId;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final EventCategory category;
  final bool isFree;
  final String venueId;
  final String venueName;
  final int capacity;
  final double ticketPrice;
  final String coverImage;
  final String status;
  final int registeredCount;
  final bool userRegistered;

  bool get isPast => endsAt.isBefore(DateTime.now());

  int get seatsLeft {
    final left = capacity - registeredCount;
    return left < 0 ? 0 : left;
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final venueRaw = json['venues'];
    final venueName = venueRaw is Map<String, dynamic>
        ? (venueRaw['name'] as String? ?? '')
        : (json['venue_name'] as String? ?? '');
    final regCount = json['registered_count'] as num?;
    final userReg = json['user_registered'] as bool?;
    return Event(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startsAt:
          DateTime.tryParse(json['starts_at'] as String? ?? '') ??
          DateTime(1970),
      endsAt:
          DateTime.tryParse(json['ends_at'] as String? ?? '') ?? DateTime(1970),
      category: EventCategory.fromDb(json['category'] as String? ?? ''),
      isFree: json['is_free'] as bool? ?? false,
      venueId: json['venue_id'] as String? ?? '',
      venueName: venueName,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      ticketPrice: (json['ticket_price'] as num?)?.toDouble() ?? 0,
      coverImage: json['cover_image'] as String? ?? '',
      status: json['status'] as String? ?? 'published',
      registeredCount: regCount?.toInt() ?? 0,
      userRegistered: userReg ?? false,
    );
  }
}

/// A user's registration / ticket for an event (`event_registrations`).
class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.quantity,
    required this.totalAmount,
    required this.status,
  });

  final String id;
  final String eventId;
  final int quantity;
  final double totalAmount;
  final String status;

  bool get isActive => status == 'registered';

  factory EventRegistration.fromResponse(Map<String, dynamic> json) =>
      EventRegistration(
        id: json['id'] as String? ?? '',
        eventId: json['event_id'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'registered',
      );
}

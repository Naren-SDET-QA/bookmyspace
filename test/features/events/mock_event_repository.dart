import 'package:bookmyspace/features/events/domain/event.dart';
import 'package:bookmyspace/features/events/domain/event_repository.dart';

/// In-memory event repository for tests and widget tests.
class MockEventRepository implements EventRepository {
  MockEventRepository();

  List<Event> upcoming = const [];
  bool failUpcoming = false;
  bool failDetail = false;
  bool failRegister = false;
  bool failCancel = false;

  String? lastRegisterEventId;
  String? lastCancelEventId;

  static Event sampleEvent({
    String id = 'e1',
    String title = 'Hyderabad Music Night',
    int capacity = 200,
    int registeredCount = 0,
    bool userRegistered = false,
  }) => Event(
    id: id,
    orgId: 'o1',
    title: title,
    description: 'An evening of live music.',
    startsAt: DateTime.now().add(const Duration(days: 14)),
    endsAt: DateTime.now().add(const Duration(days: 14, hours: 4)),
    category: EventCategory.cultural,
    isFree: false,
    venueName: 'Sunrise Function Hall',
    capacity: capacity,
    ticketPrice: 499,
    coverImage: 'https://example.com/cover.jpg',
    status: 'published',
    registeredCount: registeredCount,
    userRegistered: userRegistered,
  );

  @override
  Future<List<Event>> upcomingEvents() async {
    if (failUpcoming) throw Exception('upcoming failed');
    return upcoming;
  }

  @override
  Future<Event> eventDetail(String eventId) async {
    if (failDetail) throw Exception('detail failed');
    return upcoming.firstWhere(
      (e) => e.id == eventId,
      orElse: () => sampleEvent(),
    );
  }

  @override
  Future<EventRegistration> register({
    required String eventId,
    int quantity = 1,
  }) async {
    if (failRegister) throw Exception('register failed');
    lastRegisterEventId = eventId;
    upcoming = upcoming
        .map((e) => e.id == eventId ? _withUserRegistered(e, true) : e)
        .toList();
    return EventRegistration(
      id: 'reg1',
      eventId: eventId,
      quantity: quantity,
      totalAmount: 499.0 * quantity,
      status: 'registered',
    );
  }

  @override
  Future<void> cancelRegistration({required String eventId}) async {
    if (failCancel) throw Exception('cancel failed');
    lastCancelEventId = eventId;
    upcoming = upcoming
        .map((e) => e.id == eventId ? _withUserRegistered(e, false) : e)
        .toList();
  }

  Event _withUserRegistered(Event event, bool registered) => Event(
    id: event.id,
    orgId: event.orgId,
    title: event.title,
    description: event.description,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    category: event.category,
    isFree: event.isFree,
    venueId: event.venueId,
    venueName: event.venueName,
    capacity: event.capacity,
    ticketPrice: event.ticketPrice,
    coverImage: event.coverImage,
    status: event.status,
    registeredCount: event.registeredCount,
    userRegistered: registered,
  );
}

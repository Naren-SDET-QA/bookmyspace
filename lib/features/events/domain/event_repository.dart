import '../domain/event.dart';

/// Contract for the events feature.
abstract interface class EventRepository {
  /// Upcoming published events, soonest first.
  Future<List<Event>> upcomingEvents();

  /// A single published event with capacity + my-registration state.
  Future<Event> eventDetail(String eventId);

  /// Registers the current user for [eventId] (atomic, capacity-safe).
  Future<EventRegistration> register({
    required String eventId,
    int quantity = 1,
  });

  /// Cancels my active registration for [eventId], freeing a seat.
  Future<void> cancelRegistration({required String eventId});
}

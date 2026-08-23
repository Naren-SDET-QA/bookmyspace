import 'package:bookmyspace/features/events/domain/event.dart';
import 'package:bookmyspace/features/events/domain/event_discovery_query.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event({
  required String id,
  required String title,
  EventCategory category = EventCategory.cultural,
  bool isFree = false,
  double ticketPrice = 499,
  String venueName = 'Sunrise Function Hall',
}) {
  return Event(
    id: id,
    orgId: 'o1',
    title: title,
    description: '$title description',
    startsAt: DateTime(2026, 9, 1, 18),
    endsAt: DateTime(2026, 9, 1, 22),
    category: category,
    isFree: isFree,
    venueName: venueName,
    ticketPrice: ticketPrice,
  );
}

void main() {
  final events = [
    _event(id: 'e1', title: 'Hyderabad Music Night', category: EventCategory.cultural),
    _event(
      id: 'e2',
      title: 'Free Community Meetup',
      category: EventCategory.community,
      isFree: true,
      ticketPrice: 0,
    ),
    _event(
      id: 'e3',
      title: 'AI Workshop',
      category: EventCategory.workshop,
      venueName: 'The Boardroom',
    ),
  ];

  test('search matches title, description and venue without changing rows', () {
    final visible = const EventDiscoveryQuery(query: 'boardroom').apply(events);
    expect(visible.map((e) => e.id), ['e3']);
  });

  test('category and paid/free filters compose', () {
    final free = const EventDiscoveryQuery(
      price: EventPriceFilter.free,
    ).apply(events);
    expect(free.map((e) => e.id), ['e2']);

    final workshops = const EventDiscoveryQuery(
      category: EventCategory.workshop,
    ).apply(events);
    expect(workshops.map((e) => e.id), ['e3']);
  });

  test('empty query returns all upcoming events', () {
    expect(const EventDiscoveryQuery().apply(events), hasLength(3));
  });
}

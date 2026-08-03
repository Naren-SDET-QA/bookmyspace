import 'package:bookmyspace/features/events/domain/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventCategory', () {
    test('round-trips db values', () {
      for (final category in EventCategory.values) {
        expect(EventCategory.fromDb(category.dbValue), category);
      }
    });

    test('unknown category falls back to community', () {
      expect(EventCategory.fromDb('weird'), EventCategory.community);
    });
  });

  group('Event', () {
    test('parses a full row with venue_name + registered_count', () {
      final event = Event.fromJson({
        'id': 'e1',
        'org_id': 'o1',
        'title': 'Hyderabad Music Night',
        'starts_at': '2026-08-17T18:00:00Z',
        'ends_at': '2026-08-17T22:00:00Z',
        'category': 'cultural',
        'is_free': false,
        'venue_name': 'Sunrise Function Hall',
        'capacity': 200,
        'ticket_price': 499,
        'status': 'published',
        'registered_count': 42,
        'user_registered': true,
      });
      expect(event.title, 'Hyderabad Music Night');
      expect(event.venueName, 'Sunrise Function Hall');
      expect(event.registeredCount, 42);
      expect(event.userRegistered, isTrue);
      expect(event.seatsLeft, 158);
    });

    test('supports embedded venues map from legacy queries', () {
      final event = Event.fromJson({
        'id': 'e1',
        'title': 'AI Workshop',
        'starts_at': '2026-08-17T18:00:00Z',
        'ends_at': '2026-08-17T22:00:00Z',
        'venues': {'name': 'The Boardroom'},
        'registered_count': 2,
      });
      expect(event.venueName, 'The Boardroom');
    });

    test('isPast reflects the end time', () {
      final past = Event.fromJson({
        'title': 'x',
        'starts_at': '2020-01-01T00:00:00Z',
        'ends_at': '2020-01-01T01:00:00Z',
      });
      expect(past.isPast, isTrue);

      final future = Event.fromJson({
        'title': 'y',
        'starts_at': '2026-08-17T18:00:00Z',
        'ends_at': '2026-08-17T22:00:00Z',
      });
      expect(future.isPast, isFalse);
    });

    test('seatsLeft never goes negative', () {
      final event = Event.fromJson({
        'title': 'z',
        'starts_at': '2026-08-17T18:00:00Z',
        'ends_at': '2026-08-17T22:00:00Z',
        'capacity': 5,
        'registered_count': 9,
      });
      expect(event.seatsLeft, 0);
    });
  });

  group('EventRegistration', () {
    test('parses the RPC response', () {
      final registration = EventRegistration.fromResponse({
        'id': 'reg1',
        'event_id': 'e1',
        'quantity': 2,
        'total_amount': 998,
        'status': 'registered',
      });
      expect(registration.quantity, 2);
      expect(registration.totalAmount, 998);
      expect(registration.isActive, isTrue);
    });
  });
}

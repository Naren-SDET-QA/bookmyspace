import 'package:bookmyspace/features/meeting_rooms/domain/meeting_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meeting room parses inventory and pricing', () {
    final room = MeetingRoom.fromJson({
      'venue_id': 'room-1',
      'room_type': 'conference',
      'hourly_rate': 1000,
      'half_day_rate': 3500,
      'full_day_rate': 6500,
      'buffer_minutes': 15,
      'booking_mode': 'approval',
      'amenities': ['WiFi', 'Projector'],
      'venues': {
        'id': 'room-1',
        'name': 'Board Room',
        'capacity': 12,
        'city': 'Hyderabad',
      },
    });

    expect(room.type, MeetingRoomType.conference);
    expect(room.capacity, 12);
    expect(room.hourlyRate, 1000);
    expect(room.amenities, contains('Projector'));
    expect(room.bookingMode, 'approval');
  });

  test('quote parses availability and calculated end time', () {
    final quote = MeetingRoomQuote.fromJson({
      'available': true,
      'price': 2000,
      'end_time': '11:00:00',
    });

    expect(quote.available, isTrue);
    expect(quote.price, 2000);
    expect(quote.endTime, '11:00:00');
  });
}

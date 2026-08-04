import 'package:bookmyspace/features/sports/domain/sports_venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sports venue parses inventory, equipment and pricing', () {
    final venue = SportsVenue.fromJson({
      'venue_id': 's1',
      'sport_type': 'badminton',
      'hourly_rate': 800,
      'session_minutes': 60,
      'session_rate': 700,
      'buffer_minutes': 10,
      'booking_mode': 'instant',
      'equipment': ['Rackets'],
      'amenities': ['Changing room'],
      'venues': {'name': 'Ace Court', 'capacity': 8, 'city': 'Hyderabad'},
    });
    expect(venue.type, SportType.badminton);
    expect(venue.sessionRate, 700);
    expect(venue.equipment, contains('Rackets'));
    expect(venue.capacity, 8);
  });

  test('sports quote parses availability', () {
    final quote = SportsQuote.fromJson({
      'available': true,
      'price': 700,
      'end_time': '19:00:00',
    });
    expect(quote.available, isTrue);
    expect(quote.price, 700);
  });
}

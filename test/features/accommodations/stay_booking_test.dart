import 'package:bookmyspace/features/accommodations/domain/accommodation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses live room availability', () {
    final availability = StayUnitAvailability.fromJson({
      'unit_id': 'room-type',
      'available': 4,
      'nightly_rate': 2499.5,
    });
    expect(availability.unitId, 'room-type');
    expect(availability.available, 4);
    expect(availability.nightlyRate, 2499.5);
  });

  test('serializes multi-room selections for atomic RPC', () {
    const selection = StayRoomSelection('deluxe', 3);
    expect(selection.toJson(), {'unit_id': 'deluxe', 'quantity': 3});
  });
}

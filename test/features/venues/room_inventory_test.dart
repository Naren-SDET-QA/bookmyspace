import 'package:flutter_test/flutter_test.dart';

import 'package:bookmyspace/features/venues/domain/room_inventory.dart';

void main() {
  test('room availability rejects an overlapping stay when quantity is full', () {
    final inventory = RoomInventory(
      id: 'room-1',
      roomTypeId: 'type-1',
      name: 'Deluxe King',
      quantity: 1,
      capacity: 2,
      bedType: 'King',
      amenities: const ['Wi-Fi'],
    );

    expect(
      inventory.canReserve(
        checkIn: DateTime(2026, 8, 24),
        checkOut: DateTime(2026, 8, 26),
        reservations: const [
          RoomReservation(
            checkIn: '2026-08-24',
            checkOut: '2026-08-26',
            quantity: 1,
          ),
        ],
      ),
      isFalse,
    );
  });

  test('checkout date is non-overlapping and can reserve the room', () {
    final inventory = RoomInventory(
      id: 'room-1',
      roomTypeId: 'type-1',
      name: 'Deluxe King',
      quantity: 1,
      capacity: 2,
      bedType: 'King',
      amenities: const [],
    );

    expect(
      inventory.canReserve(
        checkIn: DateTime(2026, 8, 26),
        checkOut: DateTime(2026, 8, 28),
        reservations: const [
          RoomReservation(
            checkIn: '2026-08-24',
            checkOut: '2026-08-26',
            quantity: 1,
          ),
        ],
      ),
      isTrue,
    );
  });
}

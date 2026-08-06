import 'package:bookmyspace/features/accommodations/domain/accommodation.dart';
import 'package:bookmyspace/features/accommodations/presentation/screens/accommodation_detail_screen.dart';
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

  test('parses stay property json with booking mode and rules', () {
    final property = AccommodationProperty.fromJson({
      'id': 'prop-1',
      'module': 'stay',
      'property_type': 'hotel',
      'name': 'Grand Stay',
      'description': 'desc',
      'address': 'addr',
      'city': 'Ongole',
      'booking_mode': 'approval',
      'check_in_time': '13:00',
      'check_out_time': '10:30',
      'stay_rules': {'pets': false},
      'photos': ['a.jpg', 'b.jpg'],
      'amenities': ['Wi-Fi'],
      'food_included': false,
      'accommodation_units': [
        {
          'id': 'unit-1',
          'name': 'Deluxe',
          'occupancy_type': 'double',
          'capacity': 2,
          'inventory': 3,
          'price_nightly': 2499,
          'rent_monthly': null,
          'deposit': 0,
          'available_from': '2026-08-01',
          'amenities': [],
          'photos': [],
        },
      ],
    });
    expect(property.module, AccommodationModule.stay);
    expect(property.bookingMode, 'approval');
    expect(property.checkInTime, '13:00');
    expect(property.checkOutTime, '10:30');
    expect(property.rules, {'pets': false});
    expect(property.photos, ['a.jpg', 'b.jpg']);
    expect(property.units, hasLength(1));
    expect(property.units.first.price, 2499);
    expect(property.startingPrice, 2499);
  });

  test('stay unit price falls back to nightly rate when rent absent', () {
    final unit = AccommodationUnit(
      id: 'u1',
      name: 'Standard',
      occupancyType: 'double',
      capacity: 2,
      inventory: 1,
      rentMonthly: null,
      priceNightly: 1499,
      deposit: 0,
      availableFrom: DateTime(2026, 8, 1),
      amenities: const [],
    );
    expect(unit.price, 1499);
  });

  test('multi-night subtotal math matches server pricing', () {
    expect(computeStaySubtotal(3000, 2, 1), 6000);
    expect(computeStaySubtotal(2499, 3, 2), 14994);
    expect(computeStaySubtotal(1999, 1, 1), 1999);
  });
}

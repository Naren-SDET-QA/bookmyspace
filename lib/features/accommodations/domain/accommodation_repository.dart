import 'accommodation.dart';

abstract interface class AccommodationRepository {
  Future<List<AccommodationProperty>> search(AccommodationQuery query);
  Future<AccommodationProperty> detail(String propertyId);
  Future<String> scheduleVisit({
    required String propertyId,
    required DateTime visitAt,
  });
  Future<String> reserve(AccommodationReservationRequest request);
  Future<List<StayUnitAvailability>> availability({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
  });
}

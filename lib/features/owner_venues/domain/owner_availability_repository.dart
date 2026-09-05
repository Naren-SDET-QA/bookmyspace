import 'owner_availability.dart';

abstract interface class OwnerAvailabilityRepository {
  Future<List<OwnerOperatingHours>> hours(String venueId);
  Future<void> saveHours(String venueId, List<OwnerOperatingHours> values);
  Future<List<OwnerTimeSlot>> slots(String venueId);
  Future<OwnerTimeSlot> saveSlot(String venueId, OwnerTimeSlot slot);
  Future<void> setSlotActive(String venueId, String slotId, bool active);
  Future<void> deleteSlot(String venueId, String slotId);
}

import 'room_inventory.dart';

abstract interface class RoomInventoryRepository {
  Future<List<HotelRoomType>> roomTypesForVenue(String venueId);
}

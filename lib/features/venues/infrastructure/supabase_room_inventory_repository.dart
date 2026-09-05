import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/room_inventory.dart';
import '../domain/room_inventory_repository.dart';

class SupabaseRoomInventoryRepository implements RoomInventoryRepository {
  const SupabaseRoomInventoryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<HotelRoomType>> roomTypesForVenue(String venueId) async {
    final rows = await client
        .from('hotel_room_types')
        .select('*, hotel_room_images(url)')
        .eq('venue_id', venueId)
        .eq('is_active', true)
        .order('name');
    return rows
        .map((row) => HotelRoomType.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

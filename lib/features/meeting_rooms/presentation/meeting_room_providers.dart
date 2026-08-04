import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/meeting_room.dart';
import '../infrastructure/supabase_meeting_room_repository.dart';

final meetingRoomRepositoryProvider = Provider<MeetingRoomRepository>(
  (ref) => SupabaseMeetingRoomRepository(ref.watch(supabaseProvider)),
);
final meetingRoomsProvider = FutureProvider<List<MeetingRoom>>(
  (ref) => ref.watch(meetingRoomRepositoryProvider).rooms(),
);
final ownerMeetingRoomsProvider = FutureProvider<List<MeetingRoom>>(
  (ref) => ref.watch(meetingRoomRepositoryProvider).ownedRooms(),
);
final meetingRoomProvider = FutureProvider.family<MeetingRoom, String>(
  (ref, id) => ref.watch(meetingRoomRepositoryProvider).room(id),
);

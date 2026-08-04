import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/meeting_room.dart';
import '../meeting_room_providers.dart';

class MeetingRoomsScreen extends ConsumerStatefulWidget {
  const MeetingRoomsScreen({super.key});

  @override
  ConsumerState<MeetingRoomsScreen> createState() => _MeetingRoomsScreenState();
}

class _MeetingRoomsScreenState extends ConsumerState<MeetingRoomsScreen> {
  MeetingRoomType? type;
  int capacity = 1;

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(meetingRoomsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting & Conference Rooms')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final value in MeetingRoomType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value.name.toUpperCase()),
                      selected: type == value,
                      onSelected: (selected) =>
                          setState(() => type = selected ? value : null),
                    ),
                  ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: capacity,
                  items: [1, 4, 8, 12, 20, 50]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value+ people'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => capacity = value ?? 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: rooms.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(meetingRoomsProvider),
              ),
              data: (items) {
                final shown = items
                    .where(
                      (room) =>
                          (type == null || room.type == type) &&
                          room.capacity >= capacity,
                    )
                    .toList();
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.meeting_room_outlined,
                    title: 'No rooms found',
                    message: 'Try another room type or capacity.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(meetingRoomsProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final room = shown[index];
                      return Card(
                        child: InkWell(
                          onTap: () =>
                              context.push('/meeting-rooms/${room.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${room.type.name.toUpperCase()} • '
                                  '${room.capacity} people • ${room.city}',
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '₹${room.hourlyRate.toStringAsFixed(0)}/hour',
                                  style: const TextStyle(
                                    color: AppTheme.brand,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  children: room.amenities
                                      .take(5)
                                      .map((item) => Chip(label: Text(item)))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

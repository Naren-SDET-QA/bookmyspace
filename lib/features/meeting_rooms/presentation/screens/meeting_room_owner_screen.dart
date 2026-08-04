import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/meeting_room.dart';
import '../meeting_room_providers.dart';

class MeetingRoomOwnerScreen extends ConsumerStatefulWidget {
  const MeetingRoomOwnerScreen({super.key});
  @override
  ConsumerState<MeetingRoomOwnerScreen> createState() => _State();
}

class _State extends ConsumerState<MeetingRoomOwnerScreen> {
  final name = TextEditingController(),
      city = TextEditingController(),
      capacity = TextEditingController(text: '10'),
      hourly = TextEditingController(text: '1000'),
      half = TextEditingController(text: '3500'),
      full = TextEditingController(text: '6500');
  MeetingRoomType type = MeetingRoomType.meeting;
  bool saving = false;
  @override
  void dispose() {
    for (final c in [name, city, capacity, hourly, half, full]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> create() async {
    setState(() => saving = true);
    try {
      await ref
          .read(meetingRoomRepositoryProvider)
          .createRoom(
            name: name.text,
            description: 'Professional ${type.name} room',
            city: city.text,
            state: '',
            capacity: int.tryParse(capacity.text) ?? 1,
            type: type,
            hourlyRate: double.tryParse(hourly.text) ?? 0,
            halfDayRate: double.tryParse(half.text) ?? 0,
            fullDayRate: double.tryParse(full.text) ?? 0,
            bufferMinutes: 15,
            amenities: const ['WiFi', 'Projector', 'TV', 'AC', 'Whiteboard'],
          );
      ref.invalidate(ownerMeetingRoomsProvider);
      ref.invalidate(meetingRoomsProvider);
      if (mounted) {
        name.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Meeting room created')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(ownerMeetingRoomsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Meeting Rooms')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        children: [
          Text(
            'Inventory',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          rooms.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (items) => Column(
              children: items
                  .map(
                    (r) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room),
                        title: Text(r.name),
                        subtitle: Text(
                          '${r.capacity} people • ${r.bookingMode} • ${r.bufferMinutes}m buffer',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => _action(r, action),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'break',
                              child: Text('Add lunch break'),
                            ),
                            PopupMenuItem(
                              value: 'offline',
                              child: Text('Add offline booking'),
                            ),
                            PopupMenuItem(
                              value: 'hours',
                              child: Text('Set weekdays 09:00–18:00'),
                            ),
                            PopupMenuItem(
                              value: 'mode',
                              child: Text('Toggle Instant / Approval'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add room',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Room name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Room type'),
            items: MeetingRoomType.values
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacity'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hourly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hourly ₹'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: half,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Half-day ₹'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: full,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Full-day ₹'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : create,
            icon: const Icon(Icons.add),
            label: Text(saving ? 'Saving…' : 'Create room'),
          ),
        ],
      ),
    );
  }

  Future<void> _action(MeetingRoom room, String action) async {
    if (action == 'break') {
      await ref
          .read(meetingRoomRepositoryProvider)
          .addBreak(room.id, 0, '13:00', '14:00', 'Lunch break');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monday lunch break added')),
        );
      }
      return;
    }
    if (action == 'hours') {
      for (var day = 0; day < 5; day++) {
        await ref
            .read(meetingRoomRepositoryProvider)
            .setWorkingHours(room.id, day, '09:00', '18:00');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekday working hours updated')),
        );
      }
      return;
    }
    if (action == 'mode') {
      final mode = room.bookingMode == 'approval' ? 'instant' : 'approval';
      await ref
          .read(meetingRoomRepositoryProvider)
          .setBookingMode(room.id, mode);
      ref.invalidate(meetingRoomsProvider);
      ref.invalidate(ownerMeetingRoomsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Booking mode: $mode')));
      }
      return;
    }
    final date = DateTime.now().add(const Duration(days: 1));
    await ref
        .read(meetingRoomRepositoryProvider)
        .offlineBooking(room.id, date, '10:00', 60, 'Walk-in customer', '');
    ref.invalidate(meetingRoomsProvider);
    ref.invalidate(ownerMeetingRoomsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline booking added for tomorrow 10:00'),
        ),
      );
    }
  }
}

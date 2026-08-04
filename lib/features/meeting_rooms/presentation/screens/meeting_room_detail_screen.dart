import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../meeting_room_providers.dart';

class MeetingRoomDetailScreen extends ConsumerWidget {
  const MeetingRoomDetailScreen({super.key, required this.roomId});
  final String roomId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(meetingRoomProvider(roomId));
    return Scaffold(
      appBar: AppBar(title: const Text('Room details')),
      body: room.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(meetingRoomProvider(roomId)),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            Container(
              height: 170,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.brand,
                    AppTheme.brand.withValues(alpha: .55),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                size: 76,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              r.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              '${r.type.name.toUpperCase()} • ${r.capacity} people • ${r.city}',
            ),
            const SizedBox(height: 16),
            Text(r.description),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: r.amenities.map((a) => Chip(label: Text(a))).toList(),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _price('Hourly', r.hourlyRate),
                    _price('Half day', r.halfDayRate),
                    _price('Full day', r.fullDayRate),
                    _price(
                      'Buffer',
                      r.bufferMinutes.toDouble(),
                      suffix: ' minutes',
                    ),
                    _price('Booking', 0, suffix: r.bookingMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: room.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => context.push('/meeting-rooms/$roomId/book'),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Check availability & book'),
                ),
              ),
            ),
    );
  }

  Widget _price(String label, double value, {String? suffix}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          suffix ?? '₹${value.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

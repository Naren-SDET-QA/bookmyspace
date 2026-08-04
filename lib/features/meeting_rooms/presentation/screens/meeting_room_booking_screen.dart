import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../domain/meeting_room.dart';
import '../meeting_room_providers.dart';

class MeetingRoomBookingScreen extends ConsumerStatefulWidget {
  const MeetingRoomBookingScreen({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<MeetingRoomBookingScreen> createState() => _State();
}

class _State extends ConsumerState<MeetingRoomBookingScreen> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  String start = '09:00';
  int duration = 60;
  int repeats = 1;
  MeetingRoomQuote? quote;
  bool loading = false;
  String? error;
  Future<void> check() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = await ref
          .read(meetingRoomRepositoryProvider)
          .quote(widget.roomId, date, start, duration);
      if (mounted) setState(() => quote = q);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> book() async {
    if (quote?.available != true || loading) return;
    setState(() => loading = true);
    try {
      final rec = [
        for (var i = 1; i < repeats; i++) date.add(Duration(days: 7 * i)),
      ];
      final bookings = await ref
          .read(meetingRoomRepositoryProvider)
          .book(widget.roomId, date, start, duration, rec);
      ref.invalidate(myBookingsProvider);
      if (!mounted || bookings.isEmpty) return;
      final first = bookings.first;
      if (first.status == BookingStatus.paymentPending) {
        await context.push('/bookings/${first.id}/pay', extra: first);
      } else {
        await context.push('/bookings/${first.id}/status', extra: first);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book room')),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date'),
          subtitle: Text(DateFormat.yMMMMd().format(date)),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) {
              setState(() {
                date = d;
                quote = null;
              });
            }
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: start,
          decoration: const InputDecoration(labelText: 'Start time'),
          items: [
            for (var h = 6; h <= 21; h++)
              for (final m in ['00', '30'])
                DropdownMenuItem(
                  value: '${h.toString().padLeft(2, '0')}:$m',
                  child: Text('${h.toString().padLeft(2, '0')}:$m'),
                ),
          ],
          onChanged: (v) => setState(() {
            start = v ?? start;
            quote = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Duration'),
          items: const [
            DropdownMenuItem(value: 60, child: Text('1 hour')),
            DropdownMenuItem(value: 120, child: Text('2 hours')),
            DropdownMenuItem(value: 240, child: Text('Half day (4 hours)')),
            DropdownMenuItem(value: 480, child: Text('Full day (8 hours)')),
          ],
          onChanged: (v) => setState(() {
            duration = v ?? duration;
            quote = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: repeats,
          decoration: const InputDecoration(labelText: 'Repeat weekly'),
          items: [1, 2, 3, 4, 8, 12]
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(v == 1 ? 'Does not repeat' : '$v occurrences'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => repeats = v ?? 1),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: loading ? null : check,
          icon: const Icon(Icons.search),
          label: const Text('Check live availability'),
        ),
        if (quote != null)
          Card(
            color: quote!.available
                ? Colors.green.withValues(alpha: .1)
                : Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                quote!.available ? Icons.check_circle : Icons.block,
              ),
              title: Text(
                quote!.available
                    ? 'Available until ${quote!.endTime}'
                    : 'Unavailable',
              ),
              subtitle: Text(
                quote!.available
                    ? '₹${quote!.price.toStringAsFixed(0)} before tax'
                    : quote!.reason,
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: quote?.available == true && !loading ? book : null,
          child: Text(
            loading
                ? 'Please wait…'
                : 'Book${repeats > 1 ? ' $repeats meetings' : ''}',
          ),
        ),
      ),
    ),
  );
}

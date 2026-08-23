import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/owner_booking_calendar.dart';
import '../owner_booking_providers.dart';

/// Owner weekly occupancy from live venue bookings.
class OwnerCalendarScreen extends ConsumerWidget {
  const OwnerCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(ownerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly bookings')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(ownerBookingsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No owner bookings',
              message: 'Confirmed and pending bookings appear on this calendar.',
            );
          }
          final grouped = OwnerBookingCalendar.groupByDate(items);
          final days = grouped.keys.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final day = days[i];
              final dayBookings = grouped[day] ?? const [];
              return Card(
                child: ExpansionTile(
                  title: Text(DateFormat.yMMMMEEEEd().format(day)),
                  subtitle: Text(
                    '${dayBookings.length} booking(s) · '
                    '${OwnerBookingCalendar.confirmedCount(dayBookings)} confirmed/completed',
                  ),
                  children: [
                    for (final booking in dayBookings)
                      ListTile(
                        title: Text(
                          booking.venueName.isEmpty
                              ? booking.bookingRef
                              : booking.venueName,
                        ),
                        subtitle: Text(
                          '${booking.displayStart}–${booking.displayEnd} · ${booking.status.dbValue}',
                        ),
                        trailing: Text('₹${booking.totalAmount.toStringAsFixed(0)}'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

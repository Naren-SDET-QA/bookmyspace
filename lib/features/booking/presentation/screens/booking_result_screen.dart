import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';

class BookingResultScreen extends StatelessWidget {
  const BookingResultScreen({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final waiting = booking.status == BookingStatus.requested;
    final confirmed = booking.status == BookingStatus.confirmed;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking status')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          children: [
            const SizedBox(height: 32),
            Icon(
              waiting
                  ? Icons.hourglass_top_rounded
                  : confirmed
                  ? Icons.check_circle_rounded
                  : Icons.receipt_long_rounded,
              size: 78,
              color: waiting ? Colors.orange : AppTheme.success,
            ),
            const SizedBox(height: 18),
            Text(
              waiting ? 'Waiting for owner approval' : 'Booking confirmed',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              waiting
                  ? 'We’ll notify you as soon as the owner responds. Payment starts only after approval.'
                  : 'Your space is reserved. You can find the receipt and updates in My Bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Row('Booking ID', booking.bookingRef),
                    _Row('Hall', booking.venueName),
                    _Row('Date', DateFormat.yMMMd().format(booking.bookDate)),
                    _Row(
                      'Time',
                      '${booking.displayStart}–${booking.displayEnd}',
                    ),
                    _Row('Total', formatInr(booking.totalAmount)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.bookings),
              icon: const Icon(Icons.event_note_rounded),
              label: const Text('View My Bookings'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

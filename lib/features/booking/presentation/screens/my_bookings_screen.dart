import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../payments/presentation/payment_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';

/// Lists the signed-in user's bookings with status and cancel action.
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(myBookingsProvider);
    await ref.read(myBookingsProvider.future);
  }

  Future<void> _cancelBooking(Booking booking) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelBooking),
        content: Text(l10n.cancelBookingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(bookingRepositoryProvider).cancelBooking(booking.id);
      ref.invalidate(myBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _requestRefund(Booking booking) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.requestRefund),
        content: Text(l10n.requestRefundConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.requestRefund),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(paymentRepositoryProvider)
          .requestRefund(bookingId: booking.id, amount: booking.totalAmount);
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.refundRequested)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBookings)),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: _refresh),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: l10n.noBookings,
              message: l10n.noBookingsMessage,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BookingCard(
                  booking: list[i],
                  onShowPass: (list[i].status == BookingStatus.confirmed ||
                          list[i].status == BookingStatus.completed)
                      ? () => _showEntryPass(list[i])
                      : null,
                  onCancel: list[i].canCancel
                      ? () => _cancelBooking(list[i])
                      : null,
                  onRefund: list[i].canRefund
                      ? () => _requestRefund(list[i])
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEntryPass(Booking booking) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: AppTheme.brand),
            const SizedBox(width: 8),
            Text(
              'Digital Entry Pass',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 64,
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.bookingRef.isNotEmpty
                                ? booking.bookingRef
                                : 'BMS-PASS',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    booking.venueName.isNotEmpty
                        ? booking.venueName
                        : 'Venue Booking',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat.yMMMd().format(booking.bookDate)} • ${booking.displayStart} – ${booking.displayEnd}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (booking.slotLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      booking.slotLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Show this QR pass at the venue entrance gate for instant check-in verification.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.onShowPass,
    this.onCancel,
    this.onRefund,
  });

  final Booking booking;
  final VoidCallback? onShowPass;
  final VoidCallback? onCancel;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = booking.venueName.isEmpty ? l10n.venues : booking.venueName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (booking.slotLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          booking.slotLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: DateFormat.yMMMd().format(booking.bookDate),
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${booking.displayStart} – ${booking.displayEnd}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  booking.bookingRef,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  formatInr(booking.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (onShowPass != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onShowPass,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('View Entry Pass / QR'),
                ),
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(l10n.cancelBooking),
                ),
              ),
            ],
            if (onRefund != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRefund,
                  icon: const Icon(Icons.currency_rupee_rounded, size: 18),
                  label: Text(l10n.requestRefund),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.held => ('Held', Colors.orange),
      BookingStatus.pending => ('Pending', Colors.orange),
      BookingStatus.confirmed => ('Confirmed', Colors.green),
      BookingStatus.completed => ('Completed', Colors.blue),
      BookingStatus.cancelled => ('Cancelled', Colors.grey),
      BookingStatus.refunded => ('Refunded', Colors.teal),
      BookingStatus.noShow => ('No show', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _showCalendar = false;
  DateTime _selectedDate = DateTime.now();

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
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePadding,
                vertical: 12,
              ),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.view_list_rounded),
                      label: Text('List'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.calendar_month_rounded),
                      label: Text('Calendar'),
                    ),
                  ],
                  selected: {_showCalendar},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _showCalendar = value.first),
                ),
                const SizedBox(height: 16),
                if (_showCalendar) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: CalendarDatePicker(
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      onDateChanged: (date) =>
                          setState(() => _selectedDate = date),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    DateFormat.yMMMMd().format(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final booking in _visibleBookings(list))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BookingCard(
                      booking: booking,
                      onCancel: booking.canCancel
                          ? () => _cancelBooking(booking)
                          : null,
                      onRefund: booking.canRefund
                          ? () => _requestRefund(booking)
                          : null,
                      onPay: booking.status == BookingStatus.paymentPending
                          ? () => context.push(
                              '/bookings/${booking.id}/pay',
                              extra: booking,
                            )
                          : null,
                      onReceipt: booking.status == BookingStatus.confirmed
                          ? () =>
                                context.push('/bookings/${booking.id}/receipt')
                          : null,
                    ),
                  ),
                if (_showCalendar && _visibleBookings(list).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'Nothing booked on this day',
                      message: 'Choose another highlighted booking date.',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Booking> _visibleBookings(List<Booking> bookings) {
    if (!_showCalendar) return bookings;
    return bookings.where((booking) {
      final date = booking.bookDate;
      return date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
    }).toList();
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.onCancel,
    this.onRefund,
    this.onPay,
    this.onReceipt,
  });

  final Booking booking;
  final VoidCallback? onCancel;
  final VoidCallback? onRefund;
  final VoidCallback? onPay;
  final VoidCallback? onReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = booking.venueName.isEmpty ? l10n.venues : booking.venueName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                          fontWeight: FontWeight.w800,
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
            const Divider(height: 1, color: AppTheme.line),
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
            if (onPay != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Pay securely'),
                ),
              ),
            ],
            if (onReceipt != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onReceipt,
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('View receipt'),
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
      BookingStatus.requested => ('Approval requested', Colors.orange),
      BookingStatus.held => ('Held', Colors.orange),
      BookingStatus.approved => ('Approved', Colors.blue),
      BookingStatus.paymentPending => ('Payment pending', Colors.orange),
      BookingStatus.paid => ('Paid', Colors.teal),
      BookingStatus.pending => ('Pending', Colors.orange),
      BookingStatus.confirmed => ('Confirmed', Colors.green),
      BookingStatus.completed => ('Completed', Colors.blue),
      BookingStatus.rejected => ('Rejected', Colors.red),
      BookingStatus.cancelled => ('Cancelled', Colors.grey),
      BookingStatus.expired => ('Expired', Colors.grey),
      BookingStatus.blocked => ('Blocked', Colors.red),
      BookingStatus.refunded => ('Refunded', Colors.teal),
      BookingStatus.noShow => ('No show', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
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

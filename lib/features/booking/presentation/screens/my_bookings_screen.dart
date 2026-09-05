import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/plugin_kind.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../notifications/domain/notification.dart';
import '../../../notifications/presentation/notification_providers.dart';
import '../../../payments/presentation/payment_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';
import '../widgets/booking_status_badge.dart';

/// Lists the signed-in user's bookings with status and cancel action.
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  int _selectedTab = 0;

  Future<void> _refresh() async {
    ref.invalidate(myBookingsProvider);
    await ref.read(myBookingsProvider.future);
  }

  Future<void> _notify(
    NotificationType type,
    String title,
    String body, {
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await ref
          .read(notificationRepositoryProvider)
          .create(type: type, title: title, body: body, data: data);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Notification delivery is best-effort and must never block the action.
    }
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
      await _notify(
        NotificationType.bookingCancelled,
        l10n.cancelBooking,
        '${booking.venueName} · ${DateFormat.yMMMd().format(booking.bookDate)}',
        data: {'booking_id': booking.id},
      );
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
      await _notify(
        NotificationType.refundProcessed,
        l10n.requestRefund,
        '${booking.venueName} · ${formatInr(booking.totalAmount)}',
        data: {'booking_id': booking.id},
      );
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
          final filtered = switch (_selectedTab) {
            0 => list
                .where(
                  (booking) =>
                      booking.status == BookingStatus.confirmed ||
                      booking.status == BookingStatus.pending ||
                      booking.status == BookingStatus.held,
                )
                .toList(),
            1 => list
                .where((booking) => booking.status == BookingStatus.completed)
                .toList(),
            _ => list
                .where((booking) => booking.status == BookingStatus.cancelled)
                .toList(),
          };
          if (list.isEmpty || filtered.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: list.isEmpty ? l10n.noBookings : _emptyTabTitle(l10n),
              message: l10n.noBookingsMessage,
            );
          }
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: DefaultTabController(
                  length: 3,
                  initialIndex: _selectedTab,
                  child: TabBar(
                    onTap: (index) => setState(() => _selectedTab = index),
                    tabs: [
                      Tab(text: l10n.upcomingEvents),
                      Tab(text: l10n.statusCompleted),
                      Tab(text: l10n.statusCancelled),
                    ],
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BookingCard(
                        booking: filtered[i],
                  onShowPass:
                      (filtered[i].status == BookingStatus.confirmed ||
                          filtered[i].status == BookingStatus.completed)
                      ? () => _showEntryPass(filtered[i])
                      : null,
                  onInvoice: filtered[i].canViewInvoice
                      ? () => context.push(
                          '/bookings/${filtered[i].id}/invoice',
                          extra: filtered[i],
                        )
                      : null,
                  onCancel: filtered[i].canCancel
                      ? () => _cancelBooking(filtered[i])
                      : null,
                  onRefund: filtered[i].canRefund
                      ? () => _requestRefund(filtered[i])
                      : null,
                  onPay:
                      filtered[i].canPay &&
                          isCheckoutExposed(ref.watch(featureRegistryProvider))
                      ? () => context.push(
                          AppRoutes.paymentFlow.replaceFirst(':id', filtered[i].id),
                          extra: filtered[i],
                        )
                      : null,
                  onBookAgain: filtered[i].canBookAgain
                      ? () => context.push(
                          AppRoutes.venueDetails.replaceFirst(
                            ':id',
                            filtered[i].venueId,
                          ),
                        )
                      : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _emptyTabTitle(AppLocalizations l10n) => switch (_selectedTab) {
    0 => l10n.noUpcomingEvents,
    1 => l10n.statusCompleted,
    _ => l10n.statusCancelled,
  };

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
              l10n.digitalEntryPass,
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
                border: Border.all(color: theme.colorScheme.outlineVariant),
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
              l10n.entryPassHint,
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
    this.onInvoice,
    this.onCancel,
    this.onRefund,
    this.onPay,
    this.onBookAgain,
  });

  final Booking booking;
  final VoidCallback? onShowPass;
  final VoidCallback? onInvoice;
  final VoidCallback? onCancel;
  final VoidCallback? onRefund;
  final VoidCallback? onPay;
  final VoidCallback? onBookAgain;

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
                BookingStatusBadge(status: booking.status),
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
                  label: Text(l10n.viewEntryPass),
                ),
              ),
            ],
            if (onInvoice != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onInvoice,
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: Text(l10n.viewInvoice),
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
            if (onPay != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: Text(l10n.payNow),
                ),
              ),
            ],
            if (onBookAgain != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBookAgain,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(l10n.bookAgain),
                ),
              ),
            ],
          ],
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

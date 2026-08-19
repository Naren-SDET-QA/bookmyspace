import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/owner_booking_repository.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/widgets/booking_status_badge.dart';
import '../../../owner_venues/presentation/providers/owner_venue_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../owner_booking_providers.dart';

/// Bookings across the owner's venues with status management actions.
class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(ownerBookingsProvider);
    await ref.read(ownerBookingsProvider.future);
  }

  Future<void> _applyStatus(
    Booking booking,
    OwnerBookingAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final actionLabel = _actionLabel(action, l10n);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionLabel),
        content: Text('${booking.venueName} · '
            '${DateFormat.yMMMd().format(booking.bookDate)} · '
            '${booking.displayStart} – ${booking.displayEnd}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(ownerBookingRepositoryProvider)
          .updateStatus(booking.id, action);
      ref.invalidate(ownerBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _actionLabel(OwnerBookingAction action, AppLocalizations l10n) {
    return switch (action) {
      OwnerBookingAction.confirm => l10n.statusConfirmed,
      OwnerBookingAction.complete => l10n.completeBooking,
      OwnerBookingAction.noShow => l10n.markNoShow,
      OwnerBookingAction.cancel => l10n.cancelBooking,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookings = ref.watch(ownerBookingsProvider);
    final venues = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ownerBookings)),
      floatingActionButton: venues.when(
        data: (list) => list.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push(AppRoutes.ownerBookingCreate),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l10n.newOfflineBooking),
              ),
        loading: () => null,
        error: (_, _) => null,
      ),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: _refresh),
        data: (list) {
          if (list.isEmpty) {
            return venues.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => EmptyState(
                icon: Icons.receipt_long_rounded,
                title: l10n.noOwnerBookings,
              ),
              data: (venueList) => EmptyState(
                icon: venueList.isEmpty
                    ? Icons.storefront_rounded
                    : Icons.receipt_long_rounded,
                title: l10n.noOwnerBookings,
                message: venueList.isEmpty ? l10n.noOwnerVenuesMessage : null,
              ),
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
                child: _OwnerBookingCard(
                  booking: list[i],
                  onTap: list[i].canViewInvoice
                      ? () => context.push(
                          '/bookings/${list[i].id}/invoice',
                          extra: list[i],
                        )
                      : null,
                  onConfirm: list[i].status == BookingStatus.pending
                      ? () => _applyStatus(list[i], OwnerBookingAction.confirm)
                      : null,
                  onComplete: list[i].status == BookingStatus.confirmed
                      ? () => _applyStatus(list[i], OwnerBookingAction.complete)
                      : null,
                  onNoShow: list[i].status == BookingStatus.confirmed
                      ? () => _applyStatus(list[i], OwnerBookingAction.noShow)
                      : null,
                  onCancel: list[i].status == BookingStatus.pending ||
                          list[i].status == BookingStatus.confirmed
                      ? () => _applyStatus(list[i], OwnerBookingAction.cancel)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OwnerBookingCard extends StatelessWidget {
  const _OwnerBookingCard({
    required this.booking,
    this.onTap,
    this.onConfirm,
    this.onComplete,
    this.onNoShow,
    this.onCancel,
  });

  final Booking booking;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final customerName = booking.customerName;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                          booking.venueName.isEmpty
                              ? l10n.venues
                              : booking.venueName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (booking.isOffline) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.offlineBooking,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  BookingStatusBadge(status: booking.status),
                ],
              ),
              if (customerName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  customerName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (booking.customerPhone.isNotEmpty)
                  Text(
                    booking.customerPhone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: DateFormat.yMMMd().format(booking.bookDate),
                  ),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: '${booking.displayStart} – ${booking.displayEnd}',
                  ),
                  if (booking.slotLabel.isNotEmpty)
                    _InfoChip(icon: Icons.layers_rounded, label: booking.slotLabel),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
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
              if (onConfirm != null ||
                  onComplete != null ||
                  onNoShow != null ||
                  onCancel != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onConfirm != null)
                      FilledButton.tonal(
                        onPressed: onConfirm,
                        child: Text(l10n.statusConfirmed),
                      ),
                    if (onComplete != null)
                      FilledButton.tonal(
                        onPressed: onComplete,
                        child: Text(l10n.completeBooking),
                      ),
                    if (onNoShow != null)
                      OutlinedButton(
                        onPressed: onNoShow,
                        child: Text(l10n.markNoShow),
                      ),
                    if (onCancel != null)
                      OutlinedButton(
                        onPressed: onCancel,
                        child: Text(l10n.cancelBooking),
                      ),
                  ],
                ),
              ],
            ],
          ),
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
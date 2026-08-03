import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';

/// Booking flow: pick a date, pick an available slot, confirm the hold.
///
/// The slot lock is acquired atomically on the server (via the
/// `create-booking-hold` Edge Function) when the user confirms, then a
/// `pending` booking row is created and the payment flow is entered.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.venue});

  final Venue venue;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime? _selectedDate;
  SlotAvailability? _selectedSlot;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = _selectedDate;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookNow)),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _VenueHeader(venue: widget.venue),
                const Divider(height: 1),
                _DateStrip(
                  selected: date,
                  onSelected: (d) {
                    setState(() {
                      _selectedDate = d;
                      _selectedSlot = null;
                    });
                  },
                ),
                Expanded(
                  child: _SlotList(
                    venueId: widget.venue.id,
                    date: date,
                    selectedSlot: _selectedSlot,
                    onSelected: (slot) => setState(() {
                      _selectedSlot = slot;
                    }),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedSlot != null
          ? _ConfirmBar(
              venue: widget.venue,
              date: date!,
              slot: _selectedSlot!,
              confirming: _confirming,
              onConfirm: () => _confirmBooking(date),
            )
          : null,
    );
  }

  Future<void> _confirmBooking(DateTime date) async {
    final slot = _selectedSlot;
    if (slot == null || _confirming) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(bookingRepositoryProvider);

    final taxRate = widget.venue.taxRate;
    final amount = slot.priceAmount;
    final tax = (amount * taxRate / 100).roundToDouble();
    final total = amount + tax;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmBooking),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(label: l10n.venueDetails, value: widget.venue.name),
            _SummaryRow(
              label: l10n.selectDate,
              value: DateFormat.yMMMd().format(date),
            ),
            _SummaryRow(
              label: l10n.selectTimeSlot,
              value: '${slot.displayStart} – ${slot.displayEnd}',
            ),
            const Divider(height: 24),
            _SummaryRow(label: l10n.basePrice, value: formatInr(amount)),
            _SummaryRow(label: l10n.taxRate, value: formatInr(tax)),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.total,
              value: formatInr(total),
              emphasize: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _confirming = true);
    try {
      final hold = await repo.acquireHold(
        venueId: widget.venue.id,
        slotId: slot.slotId,
        bookDate: date,
        amount: amount,
      );
      final booking = await repo.createBooking(
        hold: hold,
        venueId: widget.venue.id,
        slotId: slot.slotId,
        bookDate: date,
        amount: amount,
        taxAmount: tax,
        totalAmount: total,
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      // Enter the payment flow with the freshly created pending booking.
      unawaited(context.push('/bookings/${booking.id}/pay', extra: booking));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}

class _VenueHeader extends StatelessWidget {
  const _VenueHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (venue.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    venue.address,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (venue.capacity > 0)
            Chip(
              avatar: const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: AppTheme.brand,
              ),
              label: Text('${venue.capacity}'),
            ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelected});

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      14,
      (i) => DateTime(today.year, today.month, today.day + i),
    );

    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected =
              date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
          return _DateChip(
            date: date,
            isSelected: isSelected,
            onTap: () => onSelected(date),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = DateFormat('EEE').format(date);
    final dayNum = DateFormat('d').format(date);
    final month = DateFormat('MMM').format(date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brand : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.brand
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayNum,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              month,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? Colors.white70
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotList extends ConsumerWidget {
  const _SlotList({
    required this.venueId,
    required this.date,
    required this.selectedSlot,
    required this.onSelected,
  });

  final String venueId;
  final DateTime date;
  final SlotAvailability? selectedSlot;
  final ValueChanged<SlotAvailability> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final availability = ref.watch(
      slotAvailabilityProvider(
        SlotAvailabilityQuery(venueId: venueId, date: date),
      ),
    );

    return availability.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(
          slotAvailabilityProvider(
            SlotAvailabilityQuery(venueId: venueId, date: date),
          ),
        ),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_rounded,
            title: l10n.noSlotsForDate,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final slot = slots[i];
            final isSelected = selectedSlot?.slotId == slot.slotId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SlotTile(
                slot: slot,
                isSelected: isSelected,
                onTap: slot.isAvailable ? () => onSelected(slot) : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final SlotAvailability slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = slot.isAvailable;

    return Material(
      color: isSelected
          ? AppTheme.brand.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppTheme.brand : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.displayStart} – ${slot.displayEnd}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!enabled)
                Text(
                  _reasonLabel(slot.reason),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatInr(slot.priceAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: isSelected
                              ? AppTheme.brand
                              : theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _reasonLabel(String reason) {
    return switch (reason) {
      'booked' => 'Booked',
      'held' => 'Unavailable',
      'blocked' => 'Blocked',
      'closed' => 'Closed',
      'inactive' => 'Closed',
      _ => 'Unavailable',
    };
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.venue,
    required this.date,
    required this.slot,
    required this.confirming,
    required this.onConfirm,
  });

  final Venue venue;
  final DateTime date;
  final SlotAvailability slot;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tax = (slot.priceAmount * venue.taxRate / 100).roundToDouble();
    final total = slot.priceAmount + tax;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.total,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatInr(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: confirming ? null : onConfirm,
                icon: confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_rounded),
                label: Text(l10n.confirmBooking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: emphasize
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasize ? AppTheme.brand : null,
            ),
          ),
        ],
      ),
    );
  }
}

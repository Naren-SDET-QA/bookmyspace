import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exceptions.dart' as app_errors;
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/prototype_controls.dart';
import '../../../../core/theme/prototype_visuals.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/domain/venue.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';

/// Booking flow: wizard with date → time → guests/extras → summary steps.
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

  // Wizard extras (client-side preview only; the server prices the slot).
  int _guests = 0;
  final Set<String> _extras = {};
  final TextEditingController _promoController = TextEditingController();
  String? _promoMessage;

  static const _demoPromo = {'BMS10': 10, 'WELCOME5': 5};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final code = _promoController.text.trim().toUpperCase();
    final percent = _demoPromo[code];
    setState(() {
      _promoMessage = percent != null
          ? 'Promo applied — ${percent}% off'
          : (code.isEmpty ? null : 'Invalid promo code');
    });
  }

  int get _promoPercent {
    final code = _promoController.text.trim().toUpperCase();
    return _demoPromo[code] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = _selectedDate;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: Text(
          l10n.bookNow,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Wizard steps: Date → Time → Guests → Summary.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
                  child: Column(
                    children: [
                      PrototypeSteps(
                        current: _selectedSlot != null ? 4 : 2,
                        total: 4,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            '📅 Date',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brand,
                            ),
                          ),
                          Text(
                            '⏰ Time',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brand,
                            ),
                          ),
                          Text(
                            '👥 Guests',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.muted,
                            ),
                          ),
                          Text(
                            '🧾 Summary',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
              guests: _guests,
              extras: _extras,
              venueFacilities: widget.venue.facilities
                  .map((f) => f.facility)
                  .toList(),
              promoPercent: _promoPercent,
              promoController: _promoController,
              promoMessage: _promoMessage,
              onPromoApply: _applyPromo,
              onGuestsChanged: (v) => setState(() => _guests = v),
              onExtrasChanged: (e, on) => setState(() {
                if (on) {
                  _extras.add(e);
                } else {
                  _extras.remove(e);
                }
              }),
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
            if (_guests > 0)
              _SummaryRow(label: 'Guests', value: '$_guests'),
            if (_extras.isNotEmpty)
              _SummaryRow(
                label: 'Extras',
                value: _extras.take(3).join(', '),
              ),
            const Divider(height: 24),
            _SummaryRow(label: l10n.basePrice, value: formatInr(amount)),
            _SummaryRow(label: l10n.taxRate, value: formatInr(tax)),
            if (_promoPercent > 0)
              _SummaryRow(
                label: 'Promo (${_promoPercent}%)',
                value: '−${formatInr(amount * _promoPercent / 100)}',
                emphasize: true,
              ),
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
      final latest = await repo.availableTimeSlots(
        venueId: widget.venue.id,
        date: date,
      );
      final liveSlot = latest.where((item) => item.slotId == slot.slotId);
      if (liveSlot.isEmpty || !liveSlot.first.isAvailable) {
        throw const app_errors.BookingConflictException(
          'This slot was just taken. Please choose another.',
          code: 'slot_unavailable',
        );
      }
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
      if (booking.status == BookingStatus.confirmed ||
          booking.status == BookingStatus.requested) {
        context.go('/bookings/${booking.id}/status', extra: booking);
      } else {
        unawaited(context.push('/bookings/${booking.id}/pay', extra: booking));
      }
    } catch (e) {
      if (!mounted) return;
      if (e is app_errors.BookingConflictException ||
          e is app_errors.HoldExpiredException) {
        setState(() => _selectedSlot = null);
        ref.invalidate(
          slotAvailabilityProvider(
            SlotAvailabilityQuery(venueId: widget.venue.id, date: date),
          ),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_bookingError(e))));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _bookingError(Object error) {
    if (error is app_errors.HoldExpiredException) {
      return 'Checkout time expired. Select the slot again to continue.';
    }
    if (error is app_errors.BookingConflictException) return error.message;
    if (error is app_errors.NetworkException ||
        error is app_errors.TimeoutException) {
      return 'Connection interrupted. Your booking was not duplicated. Please retry.';
    }
    if (error is app_errors.AppException) return error.message;
    return 'We could not complete the booking. Please try again.';
  }
}

class _VenueHeader extends StatelessWidget {
  const _VenueHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        10,
        AppTheme.pagePadding,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: PrototypeVisuals.thumbGradientFor(venue.id),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                PrototypeVisuals.emojiForCategorySlug(venue.category?.slug),
                style: PrototypeVisuals.emojiStyle(fontSize: 21),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PrototypeVisuals.softIconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    size: 14,
                    color: AppTheme.brand,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${venue.capacity}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand,
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.pagePadding,
          vertical: 8,
        ),
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
      borderRadius: BorderRadius.circular(AppTheme.compactRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 60,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brand : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.compactRadius),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.pagePadding,
            vertical: 14,
          ),
          itemCount: slots.length,
          itemBuilder: (context, i) {
            final slot = slots[i];
            final isSelected = selectedSlot?.slotId == slot.slotId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedEntrance(
                child: _SlotTile(
                  slot: slot,
                  isSelected: isSelected,
                  onTap: slot.isAvailable ? () => onSelected(slot) : null,
                ),
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
      color: isSelected ? const Color(0xFFFAF8FF) : AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.brand : AppTheme.line,
          width: isSelected ? 1.5 : 1.5,
        ),
      ),
      child: Semantics(
        label: enabled
            ? '${slot.label}, ${slot.displayStart} to ${slot.displayEnd}, ${formatInr(slot.priceAmount)}'
            : '${slot.label}, ${_reasonLabel(slot.reason)}',
        button: enabled,
        enabled: enabled,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Prototype `.slotCard .si` soft icon tile.
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PrototypeVisuals.softIconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      _slotEmoji(slot.label),
                      style: PrototypeVisuals.emojiStyle(fontSize: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8EE),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _reasonLabel(slot.reason),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.danger,
                      ),
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
                          fontWeight: FontWeight.w800,
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
                          const SizedBox(width: 4),
                          Text(
                            'Available',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _slotEmoji(String label) => switch (label.toLowerCase()) {
    'morning' => '🌅',
    'evening' => '🌆',
    'full day' || 'fullday' => '☀️',
    'community hour' => '🤝',
    _ => '⏰',
  };

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
    required this.guests,
    required this.extras,
    required this.venueFacilities,
    required this.promoPercent,
    required this.promoController,
    required this.promoMessage,
    required this.onPromoApply,
    required this.onGuestsChanged,
    required this.onExtrasChanged,
    required this.onConfirm,
  });

  final Venue venue;
  final DateTime date;
  final SlotAvailability slot;
  final bool confirming;
  final int guests;
  final Set<String> extras;
  final List<String> venueFacilities;
  final int promoPercent;
  final TextEditingController promoController;
  final String? promoMessage;
  final VoidCallback onPromoApply;
  final ValueChanged<int> onGuestsChanged;
  final void Function(String, bool) onExtrasChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tax = (slot.priceAmount * venue.taxRate / 100).roundToDouble();
    final total = slot.priceAmount + tax;
    final promoCut = (slot.priceAmount * promoPercent / 100).roundToDouble();
    final payable = total - promoCut;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Guests stepper.
              Row(
                children: [
                  const Text(
                    '👥 Guests',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                  const Spacer(),
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onTap: () => onGuestsChanged(
                      (guests - 1).clamp(0, 1000).toInt(),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$guests',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: () => onGuestsChanged(guests + 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Extras chips (venue facilities as optional add-ons).
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final facility in venueFacilities.take(8)) ...[
                      PrototypeFilterChip(
                        label: facility,
                        selected: extras.contains(facility),
                        onTap: () => onExtrasChanged(
                          facility,
                          !extras.contains(facility),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Promo code.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: promoController,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Promo code',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.muted,
                        ),
                        prefixIcon: const Icon(
                          Icons.local_offer_outlined,
                          size: 17,
                          color: AppTheme.muted,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppTheme.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                      ),
                      onSubmitted: (_) => onPromoApply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onPromoApply,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (promoMessage != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    promoMessage!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: promoMessage!.contains('applied')
                          ? AppTheme.success
                          : AppTheme.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
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
                        formatInr(payable),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrototypeButton(
                      label: l10n.confirmBooking,
                      onPressed: confirming ? null : onConfirm,
                      icon: Icons.lock_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 17, color: AppTheme.ink),
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

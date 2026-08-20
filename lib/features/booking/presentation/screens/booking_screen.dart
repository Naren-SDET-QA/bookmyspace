import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/config/settings_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';
import '../widgets/section_customer_details_form.dart';

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
  final _detailsFormKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  DateTime? _checkOutDate;
  SlotAvailability? _selectedSlot;
  bool _confirming = false;
  int _guestCount = 100;
  int _sharingIndex = 0;
  CustomerBookingDetails _details = const CustomerBookingDetails();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final user = ref.read(authNotifierProvider).user;
    _details = CustomerBookingDetails(
      fullName: user?.fullName ?? '',
      phone: user?.phone ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _selectedDate;
    final section = CustomerSectionCatalog.sectionForVenue(widget.venue);
    final l10n = AppLocalizations.of(context);
    final quickMode = ref.watch(bookingModeProvider) == BookingMode.quick;

    if (section == CustomerSection.institutesClasses) {
      return Scaffold(
        appBar: AppBar(
          title: Text(CustomerSectionCatalog.bookingScreenTitle(section)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.school_outlined,
            title: l10n.listingOnly,
            message: l10n.listingOnlyMessage,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(CustomerSectionCatalog.bookingScreenTitle(section)),
      ),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _detailsFormKey,
              child: Column(
                children: [
                  _VenueHeader(venue: widget.venue),
                  if (quickMode)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(Icons.flash_on_rounded, size: 16),
                          label: Text('Quick booking mode'),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  SectionCustomerDetailsForm(
                    section: section,
                    details: _details,
                    onChanged: (next) => setState(() => _details = next),
                  ),
                  _SectionBookingFields(
                    section: section,
                    venue: widget.venue,
                    guestCount: _guestCount,
                    checkIn: date,
                    checkOut:
                        _checkOutDate ?? date.add(const Duration(days: 1)),
                    sharingIndex: _sharingIndex,
                    onGuestsChanged: (v) => setState(() => _guestCount = v),
                    onCheckOutChanged: (v) => setState(() => _checkOutDate = v),
                    onSharingChanged: (v) => setState(() => _sharingIndex = v),
                  ),
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

  String? _validateSectionDetails(
    CustomerSection? section,
    CustomerBookingDetails details,
  ) {
    final fields = CustomerSectionCatalog.requiredCustomerFields(section);
    for (final field in fields) {
      final error = switch (field) {
        CustomerDetailField.fullName => AppValidators.name(details.fullName),
        CustomerDetailField.phone => AppValidators.phone(details.phone),
        CustomerDetailField.eventType => AppValidators.required(
          details.eventType,
          fieldName: 'Event type',
        ),
        CustomerDetailField.idNumber => AppValidators.required(
          details.idNumber,
          fieldName: 'ID number',
          minLength: 6,
        ),
        CustomerDetailField.address => AppValidators.required(
          details.address,
          fieldName: 'Address',
          minLength: 8,
        ),
      };
      if (error != null) return error;
    }
    return null;
  }

  Future<void> _confirmBooking(DateTime date) async {
    final slot = _selectedSlot;
    if (slot == null || _confirming) return;
    if (_detailsFormKey.currentState?.validate() == false) return;
    final section = CustomerSectionCatalog.sectionForVenue(widget.venue);
    final missing = _validateSectionDetails(section, _details);
    if (missing != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missing)));
      return;
    }
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(bookingRepositoryProvider);

    final taxRate = widget.venue.taxRate;
    final amount = slot.priceAmount;
    final tax = (amount * taxRate / 100).roundToDouble();
    final total = amount + tax;

    final quickMode = ref.read(bookingModeProvider) == BookingMode.quick;
    final confirmed = quickMode
        ? true
        : await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.confirmBooking),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        label: l10n.venueDetails,
                        value: widget.venue.name,
                      ),
                      _SummaryRow(
                        label: l10n.selectDate,
                        value: DateFormat.yMMMd().format(date),
                      ),
                      _SummaryRow(
                        label: l10n.selectTimeSlot,
                        value: '${slot.displayStart} – ${slot.displayEnd}',
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: l10n.basePrice,
                        value: formatInr(amount),
                      ),
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
              ) ??
              false;

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
        metadata: _bookingMetadata(date, section),
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.slotHeld)));
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

  /// Section-specific extras (guests, check-out, sharing) recorded on the
  /// booking's `metadata` jsonb column for the invoice and owner records.
  Map<String, dynamic> _bookingMetadata(
    DateTime date,
    CustomerSection? section,
  ) {
    return {
      'customer_name': _details.fullName,
      'customer_phone': _details.phone,
      'full_name': _details.fullName,
      'phone': _details.phone,
      if (section == CustomerSection.functionHalls) 'guests': _guestCount,
      if (section == CustomerSection.lodgeRooms)
        'checkout_date':
            '${(_checkOutDate ?? date.add(const Duration(days: 1))).year.toString().padLeft(4, '0')}-'
            '${(_checkOutDate ?? date.add(const Duration(days: 1))).month.toString().padLeft(2, '0')}-'
            '${(_checkOutDate ?? date.add(const Duration(days: 1))).day.toString().padLeft(2, '0')}',
      if (section == CustomerSection.pgHostels) ...{
        'sharing': _sharingIndex,
        'deposit': widget.venue.pricingBaseAmount,
      },
    };
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
    final l10n = AppLocalizations.of(context);
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
                  _reasonLabel(slot.reason, l10n),
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

  String _reasonLabel(String reason, AppLocalizations l10n) {
    return switch (reason) {
      'booked' => l10n.slotBooked,
      'held' => l10n.slotUnavailable,
      'blocked' => l10n.slotBlocked,
      'closed' => l10n.slotClosed,
      'inactive' => l10n.slotClosed,
      _ => l10n.slotUnavailable,
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

class _SectionBookingFields extends StatelessWidget {
  const _SectionBookingFields({
    required this.section,
    required this.venue,
    required this.guestCount,
    required this.checkIn,
    required this.checkOut,
    required this.sharingIndex,
    required this.onGuestsChanged,
    required this.onCheckOutChanged,
    required this.onSharingChanged,
  });

  final CustomerSection? section;
  final Venue venue;
  final int guestCount;
  final DateTime checkIn;
  final DateTime checkOut;
  final int sharingIndex;
  final ValueChanged<int> onGuestsChanged;
  final ValueChanged<DateTime> onCheckOutChanged;
  final ValueChanged<int> onSharingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (section == null || section == CustomerSection.functionHalls) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Text(l10n.guestCount),
            const Spacer(),
            IconButton(
              onPressed: guestCount > 10
                  ? () => onGuestsChanged(guestCount - 10)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$guestCount'),
            IconButton(
              onPressed: () => onGuestsChanged(guestCount + 10),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      );
    }

    if (section == CustomerSection.lodgeRooms) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.checkIn} ${DateFormat.MMMd().format(checkIn)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: checkOut,
                  firstDate: checkIn.add(const Duration(days: 1)),
                  lastDate: checkIn.add(const Duration(days: 30)),
                );
                if (picked != null) onCheckOutChanged(picked);
              },
              child: Text(
                '${l10n.checkOut} ${DateFormat.MMMd().format(checkOut)}',
              ),
            ),
          ],
        ),
      );
    }

    if (section == CustomerSection.pgHostels) {
      final deposit = venue.pricingBaseAmount;
      final totalMoveIn = venue.pricingBaseAmount + deposit;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.moveIn} ${DateFormat.yMMMd().format(checkIn)} · '
              '${l10n.sharingOption} ${sharingIndex + 1}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.rent} ${formatInr(venue.pricingBaseAmount)} + '
              '${l10n.deposit} ${formatInr(deposit)} = ${formatInr(totalMoveIn)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => onSharingChanged((sharingIndex + 1) % 3),
                child: Text(l10n.changeSharing),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

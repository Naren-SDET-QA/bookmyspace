import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../owner_venues/presentation/providers/owner_venue_providers.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../owner_booking_providers.dart';

/// Walk-in (offline) booking flow for owners: venue, date, slot and customer.
class CreateOfflineBookingScreen extends ConsumerStatefulWidget {
  const CreateOfflineBookingScreen({super.key});

  @override
  ConsumerState<CreateOfflineBookingScreen> createState() =>
      _CreateOfflineBookingScreenState();
}

class _CreateOfflineBookingScreenState
    extends ConsumerState<CreateOfflineBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  Venue? _venue;
  DateTime _date = DateTime.now();
  SlotAvailability? _slot;
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final venues = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createOfflineBooking)),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.storefront_rounded,
              title: l10n.noOwnerVenuesMessage,
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VenuePicker(
                  venues: list,
                  selected: _venue,
                  onChanged: (v) => setState(() {
                    _venue = v;
                    _slot = null;
                  }),
                ),
                if (_venue != null) ...[
                  const SizedBox(height: 16),
                  _DateStrip(
                    selected: _date,
                    onSelected: (d) => setState(() {
                      _date = d;
                      _slot = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: l10n.customerName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => AppValidators.name(v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.customerPhone,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => AppValidators.phone(v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  _SlotList(
                    venueId: _venue!.id,
                    date: _date,
                    selectedSlot: _slot,
                    onSelected: (s) => setState(() => _slot = s),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _slot == null || _venue == null
          ? null
          : _CreateBar(
              venue: _venue!,
              slot: _slot!,
              creating: _creating,
              onCreate: _create,
            ),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final venue = _venue;
    final slot = _slot;
    if (venue == null || slot == null || _creating) return;
    if (_formKey.currentState?.validate() != true) return;

    final tax = (slot.priceAmount * venue.taxRate / 100).roundToDouble();
    final total = slot.priceAmount + tax;

    setState(() => _creating = true);
    try {
      await ref.read(ownerBookingRepositoryProvider).createOfflineBooking(
        venueId: venue.id,
        slotId: slot.slotId,
        bookDate: _date,
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        amount: slot.priceAmount,
        taxAmount: tax,
        totalAmount: total,
      );
      ref.invalidate(ownerBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookingConfirmed)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _VenuePicker extends StatelessWidget {
  const _VenuePicker({
    required this.venues,
    required this.selected,
    required this.onChanged,
  });

  final List<Venue> venues;
  final Venue? selected;
  final ValueChanged<Venue> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<Venue>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.selectVenue,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final v in venues)
          DropdownMenuItem(value: v, child: Text(v.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelected});

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final dates = List.generate(
      30,
      (i) => DateTime(today.year, today.month, today.day + i),
    );
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected =
              date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
          return InkWell(
            onTap: () => onSelected(date),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.brand
                    : theme.colorScheme.surface,
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
                    DateFormat('EEE').format(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d').format(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
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
        },
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
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorView(message: e.toString()),
      data: (slots) {
        if (slots.isEmpty) {
          return EmptyState(icon: Icons.event_busy_rounded, title: l10n.noSlotsForDate);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectTimeSlot,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final slot in slots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SlotTile(
                  slot: slot,
                  isSelected: selectedSlot?.slotId == slot.slotId,
                  onTap: slot.isAvailable ? () => onSelected(slot) : null,
                ),
              ),
          ],
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
    return Material(
      color: isSelected
          ? AppTheme.brand.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.brand : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    Text(
                      '${slot.displayStart} – ${slot.displayEnd}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatInr(slot.priceAmount),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateBar extends StatelessWidget {
  const _CreateBar({
    required this.venue,
    required this.slot,
    required this.creating,
    required this.onCreate,
  });

  final Venue venue;
  final SlotAvailability slot;
  final bool creating;
  final VoidCallback onCreate;

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
                onPressed: creating ? null : onCreate,
                icon: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l10n.createOfflineBooking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
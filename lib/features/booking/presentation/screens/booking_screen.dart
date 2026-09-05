import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/config/settings_controller.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/feature_id.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/modular/plugin_kind.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../home/domain/customer_section_catalog.dart';
import '../../../venues/domain/category_configuration.dart';
import '../../../venues/domain/category_discovery.dart';
import '../../../venues/domain/category_registration.dart';
import '../../../venues/domain/venue.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../../domain/configurable_booking.dart';
import '../booking_providers.dart';
import '../widgets/configurable_booking_fields_form.dart';
import '../widgets/section_customer_details_form.dart';
import '../../../support/presentation/widgets/contextual_help_button.dart';

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
  DateTime? _selectedCheckoutDate;
  SlotAvailability? _selectedSlot;
  bool _confirming = false;
  BookingFieldValues _fieldValues = const BookingFieldValues({'guests': 100});
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
    final config = _categoryConfig(ref);
    final listingOnly =
        config?.isListingOnly ?? section == CustomerSection.institutesClasses;
    final bookingFields = ConfigurableBookingFields.resolve(
      config: config,
      sectionId: section?.id,
      registry: ref.watch(featureRegistryProvider),
    );
    final l10n = AppLocalizations.of(context);
    final quickMode = ref.watch(bookingModeProvider) == BookingMode.quick;
    final isSignedIn = ref.watch(authNotifierProvider).user != null;

    if (listingOnly) {
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
        actions: [
          const ContextualHelpButton(route: AppRoutes.bookingFlow),
          if (ref.watch(featureRegistryProvider).isExposed(FeatureId.ai))
            IconButton(
              tooltip: 'Ask Assistant',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => context.push(AppRoutes.assistant),
            ),
        ],
      ),
      body: date == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _detailsFormKey,
              child: Column(
                children: [
                  _VenueHeader(venue: widget.venue),
                  if (quickMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: const Icon(Icons.flash_on_rounded, size: 16),
                          label: Text(l10n.quickBookingMode),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  SectionCustomerDetailsForm(
                    section: section,
                    details: _details,
                    onChanged: (next) => setState(() => _details = next),
                  ),
                  ConfigurableBookingFieldsForm(
                    fields: bookingFields,
                    values: _fieldValues,
                    onChanged: (next) => setState(() => _fieldValues = next),
                  ),
                  if (section == CustomerSection.lodgeRooms)
                    _CheckoutDateField(
                      selected: _selectedCheckoutDate,
                      onSelected: (date) => setState(() {
                        _selectedCheckoutDate = date;
                      }),
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
      bottomNavigationBar: _selectedSlot == null
          ? null
          : isSignedIn
          ? _ConfirmBar(
              venue: widget.venue,
              date: date!,
              slot: _selectedSlot!,
              confirming: _confirming,
              onConfirm: () => _confirmBooking(date),
            )
          : _SignInRequiredBar(onSignIn: () => _promptSignIn()),
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
    if (ref.read(authNotifierProvider).user == null) {
      // Defense in depth: the Confirm action is not rendered while signed
      // out (see build()), but guard the entry point directly too so a
      // stale build or a future caller can never acquire a hold without an
      // authenticated session.
      unawaited(_promptSignIn());
      return;
    }
    final category = _categoryConfig(ref);
    if (!CategoryDiscovery.canBook(category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).bookingDisabledForCategory,
          ),
        ),
      );
      return;
    }
    if (category != null && !category.availabilityEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).availabilityDisabledForCategory,
          ),
        ),
      );
      return;
    }
    if (_detailsFormKey.currentState?.validate() == false) return;
    final section = CustomerSectionCatalog.sectionForVenue(widget.venue);
    if (section == CustomerSection.lodgeRooms &&
        _selectedCheckoutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete your booking details: Check-out is required'),
        ),
      );
      return;
    }
    final missing = _validateSectionDetails(section, _details);
    if (missing != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missing)));
      return;
    }
    final config = category;
    final bookingFields = ConfigurableBookingFields.resolve(
      config: config,
      sectionId: section?.id,
      registry: ref.read(featureRegistryProvider),
    );
    final missingBooking = _fieldValues.missing(bookingFields);
    if (missingBooking.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).fieldsRequired(missingBooking.join(', ')),
          ),
        ),
      );
      return;
    }
    final registration = CategoryRegistrationConfig.from(config);
    if (registration.enforcedForBooking) {
      final missingRegistration = registration.missing({
        'full_name': _details.fullName,
        'phone': _details.phone,
        'customer_name': _details.fullName,
        'customer_phone': _details.phone,
        ..._fieldValues.values,
      });
      if (missingRegistration.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).fieldsRequired(missingRegistration.join(', ')),
            ),
          ),
        );
        return;
      }
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
        metadata: {
          'customer_name': _details.fullName,
          'customer_phone': _details.phone,
          'full_name': _details.fullName,
          'phone': _details.phone,
          if (_selectedCheckoutDate != null)
            'check_out': _selectedCheckoutDate!.toIso8601String(),
          'hold_expires_at': hold.expiresAt.toUtc().toIso8601String(),
          ..._fieldValues.toMetadata(),
        },
      );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.holdExpiresIn(HoldCountdown.format(hold.remaining())),
          ),
        ),
      );
      if (isCheckoutExposed(ref.read(featureRegistryProvider))) {
        unawaited(context.push('/bookings/${booking.id}/pay', extra: booking));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is AppException ? e.message : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// Sends a signed-out user to the existing login flow and returns them
  /// here afterwards. Uses `push` (not `go`) so this screen -- and every
  /// field of booking state held on it -- is kept alive underneath, not
  /// disposed; [LoginScreen] pops back to it on a successful sign-in
  /// instead of navigating to the shell (see LoginScreen._onSignedIn).
  Future<void> _promptSignIn() async {
    await context.push(AppRoutes.login);
  }

  CategoryConfiguration? _categoryConfig(WidgetRef ref) {
    final configs =
        ref.watch(categoryConfigurationsProvider).valueOrNull ?? const [];
    final slug = widget.venue.category?.slug;
    final id = widget.venue.category?.id;
    for (final item in configs) {
      if (item.id == id || item.slug == slug) return item;
    }
    return null;
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

class _CheckoutDateField extends StatelessWidget {
  const _CheckoutDateField({required this.selected, required this.onSelected});

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? 'Check-out: Select date'
        : 'Check-out: ${DateFormat('EEE, d MMM').format(selected!)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: OutlinedButton.icon(
        key: const Key('booking_checkout_date'),
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
            initialDate: selected ?? now.add(const Duration(days: 1)),
          );
          if (picked != null) onSelected(picked);
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(label),
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

/// Shown instead of [_ConfirmBar] when no user is signed in. Booking
/// details already entered on this screen are preserved -- this widget
/// only blocks the final "acquire a booking hold" call, which requires an
/// authenticated Supabase session server-side regardless of this UI gate.
class _SignInRequiredBar extends StatelessWidget {
  const _SignInRequiredBar({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.signInRequiredForBooking,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.signInToContinue),
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

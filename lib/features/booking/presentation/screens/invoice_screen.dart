import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/booking.dart';
import '../booking_providers.dart';

/// Read-only invoice for a paid booking (confirmed / completed / refunded).
///
/// Refreshes the booking from the server when an [initial] booking is passed
/// so payment details captured by the webhook are reflected.
class InvoiceScreen extends ConsumerWidget {
  const InvoiceScreen({super.key, this.bookingId, this.initial});

  final String? bookingId;
  final Booking? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = bookingId ?? initial?.id;
    final booking = ref.watch(bookingByIdProvider(id ?? ''));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.invoice)),
      body: id == null
          ? const ErrorView(message: 'Missing booking id')
          : booking.when(
              loading: initial != null
                  ? () => _InvoiceBody(booking: initial!)
                  : () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (b) => _InvoiceBody(booking: b),
            ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      color: AppTheme.brand,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.invoiceFor,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Row(label: l10n.bookingRef, value: booking.bookingRef),
                _Row(label: l10n.bookingStatus, value: _statusLabel(booking.status, l10n)),
                _Row(
                  label: l10n.dateOfBooking,
                  value: DateFormat.yMMMd().format(booking.bookDate),
                ),
                _Row(
                  label: l10n.selectTimeSlot,
                  value: '${booking.displayStart} – ${booking.displayEnd}',
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
                const Divider(height: 28),
                Text(
                  booking.venueName.isNotEmpty
                      ? booking.venueName
                      : l10n.venues,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (booking.venueCity.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    booking.venueCity,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (booking.customerName.isNotEmpty ||
                    booking.customerPhone.isNotEmpty) ...[
                  const Divider(height: 28),
                  Text(
                    l10n.customer,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (booking.customerName.isNotEmpty)
                    _Row(label: l10n.name, value: booking.customerName),
                  if (booking.customerPhone.isNotEmpty)
                    _Row(label: l10n.phone, value: booking.customerPhone),
                ],
                if (_metadataExtras(l10n).isNotEmpty) ...[
                  const Divider(height: 28),
                  ..._metadataExtras(l10n).entries.map(
                    (e) => _Row(label: e.key, value: e.value),
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          color: AppTheme.brand.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _Row(label: l10n.basePrice, value: formatInr(booking.amount)),
                _Row(label: l10n.taxRate, value: formatInr(booking.taxAmount)),
                const Divider(height: 24),
                _Row(
                  label: l10n.total,
                  value: formatInr(booking.totalAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        if (booking.paymentMethod.isNotEmpty || booking.paymentRef.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _Row(
                    label: l10n.payMethod,
                    value: booking.isOffline
                        ? l10n.offlinePayment
                        : l10n.onlinePayment,
                  ),
                  if (booking.paymentRef.isNotEmpty)
                    _Row(label: l10n.paymentRef, value: booking.paymentRef),
                  if (booking.paidAt != null)
                    _Row(
                      label: l10n.paidOn,
                      value: DateFormat.yMMMd().add_jm().format(booking.paidAt!),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Map<String, String> _metadataExtras(AppLocalizations l10n) {
    final extras = <String, String>{};
    final guests = booking.metadata['guests'];
    if (guests is num) extras[l10n.guestCount] = guests.toString();
    final checkout = booking.metadata['checkout_date'];
    if (checkout is String && checkout.isNotEmpty) {
      final parsed = DateTime.tryParse(checkout);
      if (parsed != null) extras[l10n.checkOut] = DateFormat.yMMMd().format(parsed);
    }
    final sharing = booking.metadata['sharing'];
    if (sharing is num) extras[l10n.sharingOption] = '${sharing + 1}';
    final deposit = booking.metadata['deposit'];
    if (deposit is num) extras[l10n.deposit] = formatInr(deposit.toDouble());
    return extras;
  }

  String _statusLabel(BookingStatus status, AppLocalizations l10n) {
    return switch (status) {
      BookingStatus.held => l10n.statusHeld,
      BookingStatus.pending => l10n.statusPending,
      BookingStatus.confirmed => l10n.statusConfirmed,
      BookingStatus.completed => l10n.statusCompleted,
      BookingStatus.cancelled => l10n.statusCancelled,
      BookingStatus.refunded => l10n.statusRefunded,
      BookingStatus.noShow => l10n.statusNoShow,
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(width: 16),
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

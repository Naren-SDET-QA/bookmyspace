import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking.dart';
import '../../../booking/presentation/booking_providers.dart';
import '../../../notifications/domain/notification.dart';
import '../../../notifications/presentation/notification_providers.dart';
import '../../../venues/presentation/widgets/venue_badges.dart';
import '../../domain/checkout_service.dart';
import '../payment_providers.dart';

/// Payment flow: creates a Razorpay order for a freshly made pending booking,
/// opens checkout, then reflects the webhook-driven confirmation.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

enum _PaymentPhase { idle, creatingOrder, checkout, verifying, done, error }

enum _PaymentMethod { online, payAtVenue }

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  _PaymentPhase _phase = _PaymentPhase.idle;
  String? _errorMessage;
  bool _confirmed = false;
  Timer? _pollTimer;

  // The booking mutates locally once a promo code changes its discount /
  // total; everything below reads from this instead of widget.booking.
  late Booking _booking = widget.booking;
  final _promoController = TextEditingController();
  bool _applyingCoupon = false;
  String? _couponError;
  String? _appliedCode;
  _PaymentMethod _paymentMethod = _PaymentMethod.online;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty || _applyingCoupon) return;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });
    try {
      final updated = await ref
          .read(bookingRepositoryProvider)
          .applyCoupon(bookingId: _booking.id, code: code);
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _appliedCode = code.toUpperCase();
        _applyingCoupon = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applyingCoupon = false;
        _couponError = e.toString();
      });
    }
  }

  Future<void> _removePromo() async {
    if (_applyingCoupon) return;
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });
    try {
      final updated = await ref
          .read(bookingRepositoryProvider)
          .removeCoupon(_booking.id);
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _appliedCode = null;
        _promoController.clear();
        _applyingCoupon = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applyingCoupon = false;
        _couponError = e.toString();
      });
    }
  }

  Future<void> _pay() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _phase = _PaymentPhase.creatingOrder);
    try {
      final order = await ref
          .read(paymentRepositoryProvider)
          .createOrder(bookingId: _booking.id);
      if (!mounted) return;
      setState(() => _phase = _PaymentPhase.checkout);

      final checkout = ref.read(checkoutServiceProvider);
      final result = await checkout.openCheckout(
        orderId: order.orderId,
        amount: order.amount,
        currency: order.currency,
        keyId: AppConfig.razorpayKeyId,
      );
      if (!mounted) return;

      if (result == CheckoutResult.paid) {
        _startVerification();
      } else if (result == CheckoutResult.cancelled) {
        setState(() {
          _phase = _PaymentPhase.idle;
          _errorMessage = l10n.paymentCancelled;
        });
      } else if (result == CheckoutResult.timedOut) {
        setState(() {
          _phase = _PaymentPhase.error;
          _errorMessage = 'Payment checkout timed out. Please try again.';
        });
      } else {
        setState(() {
          _phase = _PaymentPhase.error;
          _errorMessage = l10n.paymentFailed;
        });
      }
    } on ConfigurationException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(e.toString());
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _PaymentPhase.error;
      _errorMessage = message;
    });
  }

  /// Commits the booking to "pay at venue" — no Razorpay order is ever
  /// created. The server (select_pay_at_venue) is the sole authority on
  /// whether this is allowed; it re-validates ownership and booking state
  /// and always lands the booking in the same owner-approval queue a
  /// captured online payment reaches, so the result is shown with the
  /// same "pending approval" screen as an unconfirmed online payment.
  Future<void> _payAtVenue() async {
    setState(() => _phase = _PaymentPhase.creatingOrder);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .selectPayAtVenue(bookingId: _booking.id);
      if (!mounted) return;
      ref.invalidate(myBookingsProvider);
      setState(() {
        _phase = _PaymentPhase.done;
        _confirmed = false;
      });
    } catch (e) {
      _fail(e.toString());
    }
  }

  /// After a successful checkout, poll the booking until the webhook has
  /// flipped it to `confirmed` (or a terminal state).
  void _startVerification() {
    setState(() => _phase = _PaymentPhase.verifying);
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      try {
        final status = await ref
            .read(paymentRepositoryProvider)
            .bookingStatus(_booking.id);
        if (!mounted) return;
        if (status == BookingStatus.confirmed ||
            status == BookingStatus.cancelled ||
            status == BookingStatus.refunded) {
          timer.cancel();
          ref.invalidate(myBookingsProvider);
          setState(() {
            _phase = _PaymentPhase.done;
            _confirmed = status == BookingStatus.confirmed;
          });
          if (status == BookingStatus.confirmed) {
            unawaited(_recordConfirmedNotification());
          }
        } else if (attempts > 10) {
          // The webhook may be delayed; hand control back to the user.
          timer.cancel();
          setState(() {
            _phase = _PaymentPhase.done;
            _confirmed = false;
          });
        }
      } catch (_) {
        // Ignore transient polling errors; keep trying.
      }
    });
  }

  /// In-app notification when the webhook confirms the booking.
  Future<void> _recordConfirmedNotification() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .create(
            type: NotificationType.bookingConfirmed,
            title: l10n.statusConfirmed,
            body:
                '${_booking.venueName} · ${DateFormat.yMMMd().format(_booking.bookDate)}',
            data: {'booking_id': _booking.id},
          );
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      // Best-effort; never block the payment flow.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.payment)),
      body: switch (_phase) {
        _PaymentPhase.idle => _buildIdle(context),
        _PaymentPhase.creatingOrder => const Center(
          child: CircularProgressIndicator(),
        ),
        _PaymentPhase.checkout => const Center(
          child: CircularProgressIndicator(),
        ),
        _PaymentPhase.verifying => _buildVerifying(context, l10n),
        _PaymentPhase.done => _buildDone(context, l10n),
        _PaymentPhase.error => _buildError(context, l10n),
      },
      bottomNavigationBar: _phase == _PaymentPhase.idle
          ? _PayBar(
              total: _booking.totalAmount,
              method: _paymentMethod,
              onConfirm: _paymentMethod == _PaymentMethod.online
                  ? _pay
                  : _payAtVenue,
            )
          : null,
    );
  }

  Widget _buildIdle(BuildContext context) {
    // The payment-method and promo controls live in a fixed (non-scrolling)
    // footer below the summary, not inside the ListView. Only the
    // (potentially long) read-only summary scrolls; the interactive
    // controls are always fully on-screen and reachable without scrolling,
    // regardless of viewport height.
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [_SummaryCard(booking: _booking)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_booking.canPay) ...[
                _PaymentMethodCard(
                  selected: _paymentMethod,
                  onChanged: (method) =>
                      setState(() => _paymentMethod = method),
                ),
                const SizedBox(height: 12),
              ],
              if (_booking.canPay)
                _PromoCodeCard(
                  controller: _promoController,
                  appliedCode: _appliedCode,
                  discountAmount: _booking.discountAmount,
                  busy: _applyingCoupon,
                  error: _couponError,
                  onApply: _applyPromo,
                  onRemove: _removePromo,
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifying(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.verifyingPayment,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _confirmed
                  ? Icons.check_circle_rounded
                  : Icons.pending_actions_rounded,
              size: 72,
              color: _confirmed ? Colors.green : theme.colorScheme.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _confirmed ? l10n.paymentSuccess : l10n.paymentPending,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _confirmed
                  ? '${l10n.bookingConfirmed} ${_booking.bookingRef}'
                  : l10n.paymentPendingMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.invalidate(myBookingsProvider);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? l10n.paymentFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.booking});

  final Booking booking;

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
            Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            if (booking.slotLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoChip(icon: Icons.layers_rounded, label: booking.slotLabel),
            ],
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.basePrice,
              value: formatInr(booking.amount),
            ),
            _SummaryRow(
              label: l10n.taxRate,
              value: formatInr(booking.taxAmount),
            ),
            if (booking.discountAmount > 0)
              _SummaryRow(
                label: l10n.discount,
                value: '- ${formatInr(booking.discountAmount)}',
              ),
            const Divider(height: 24),
            _SummaryRow(
              label: l10n.total,
              value: formatInr(booking.totalAmount),
              emphasize: true,
            ),
            const SizedBox(height: 8),
            Text(
              booking.bookingRef,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.method,
    required this.onConfirm,
  });

  final double total;
  final _PaymentMethod method;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = method == _PaymentMethod.online;
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
                onPressed: onConfirm,
                icon: Icon(
                  online ? Icons.lock_rounded : Icons.storefront_rounded,
                ),
                label: Text(online ? l10n.payNow : l10n.confirmBooking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({required this.selected, required this.onChanged});

  final _PaymentMethod selected;
  final ValueChanged<_PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final online = selected == _PaymentMethod.online;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paymentMethod,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: online
                      ? FilledButton.icon(
                          onPressed: () => onChanged(_PaymentMethod.online),
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: Text(l10n.onlinePayment),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => onChanged(_PaymentMethod.online),
                          icon: const Icon(Icons.lock_rounded, size: 18),
                          label: Text(l10n.onlinePayment),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: online
                      ? OutlinedButton.icon(
                          onPressed: () =>
                              onChanged(_PaymentMethod.payAtVenue),
                          icon: const Icon(
                            Icons.storefront_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.payAtVenue),
                        )
                      : FilledButton.icon(
                          onPressed: () =>
                              onChanged(_PaymentMethod.payAtVenue),
                          icon: const Icon(
                            Icons.storefront_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.payAtVenue),
                        ),
                ),
              ],
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

class _PromoCodeCard extends StatelessWidget {
  const _PromoCodeCard({
    required this.controller,
    required this.appliedCode,
    required this.discountAmount,
    required this.busy,
    required this.error,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String? appliedCode;
  final double discountAmount;
  final bool busy;
  final String? error;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // discountAmount can be > 0 without a locally-known code (e.g. this
    // screen was recreated after the coupon was applied in an earlier
    // visit) — still show the applied state, just without the code text.
    final applied = discountAmount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.promoCode,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (applied)
              Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appliedCode != null
                          ? '${l10n.promoCodeApplied}: $appliedCode '
                                '(- ${formatInr(discountAmount)})'
                          : '${l10n.promoCodeApplied} '
                                '(- ${formatInr(discountAmount)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : onRemove,
                    child: Text(l10n.remove),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !busy,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.promoCodeHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => onApply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: busy ? null : onApply,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.apply),
                  ),
                ],
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../invoices/presentation/invoice_providers.dart';
import '../../domain/checkout_service.dart';
import '../payment_providers.dart';

class CommercePaymentScreen extends ConsumerStatefulWidget {
  const CommercePaymentScreen({
    super.key,
    required this.referenceId,
    required this.amount,
    required this.currency,
  });
  final String referenceId, currency;
  final double amount;
  @override
  ConsumerState<CommercePaymentScreen> createState() => _CommercePaymentState();
}

class _CommercePaymentState extends ConsumerState<CommercePaymentScreen> {
  bool busy = false;
  String? message;
  Future<void> pay() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final order = await repo.createCommerceOrder(
        referenceId: widget.referenceId,
      );
      final result = await ref
          .read(checkoutServiceProvider)
          .openCheckout(
            orderId: order.orderId,
            amount: order.amount,
            currency: order.currency,
            keyId: order.keyId ?? AppConfig.razorpayKeyId,
          );
      if (result != CheckoutResult.paid) {
        if (mounted) {
          setState(() {
            busy = false;
            message = result == CheckoutResult.cancelled
                ? 'Payment cancelled'
                : 'Payment failed';
          });
        }
        return;
      }
      for (var attempt = 0; attempt < 20; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await repo.commerceStatus(widget.referenceId) == 'confirmed') {
          final invoiceId = await ref
              .read(invoiceRepositoryProvider)
              .issueCommerce(referenceId: widget.referenceId);
          if (mounted) {
            context.go(AppRoutes.invoiceView.replaceFirst(':id', invoiceId));
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          busy = false;
          message = 'Payment is still being verified. Reopen this page safely.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          message = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Secure payment')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (message != null) Text(message!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : pay,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock),
              label: Text(busy ? 'Verifying...' : 'Pay now'),
            ),
          ],
        ),
      ),
    ),
  );
}

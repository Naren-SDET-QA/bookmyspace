import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/pricing_feature.dart';

/// Contact access UI. Payment creation is injected by the existing payment
/// flow; this widget never trusts or sends a client-supplied amount.
class ContactAccessCard extends StatefulWidget {
  const ContactAccessCard({
    super.key,
    required this.label,
    required this.feature,
    required this.onPurchase,
    required this.onReveal,
  });

  final String label;
  final PricingFeature feature;
  final Future<void> Function() onPurchase;
  final Future<String?> Function() onReveal;

  @override
  State<ContactAccessCard> createState() => _ContactAccessCardState();
}

class _ContactAccessCardState extends State<ContactAccessCard> {
  bool _loading = false;
  String? _value;

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact access failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.feature.amountMinor == 0;
    final price = NumberFormat.currency(
      name: widget.feature.currency,
      decimalDigits: 2,
    ).format(widget.feature.amountMinor / 100);
    return Card(
      child: ListTile(
        leading: Icon(_value == null ? Icons.lock_outline : Icons.lock_open),
        title: Text(widget.label),
        subtitle: Text(_value ?? (isFree ? 'Available' : 'Contact hidden')),
        trailing: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton(
                onPressed: () => _run(() async {
                  if (_value == null && !isFree) {
                    await widget.onPurchase();
                  }
                  final value = await widget.onReveal();
                  if (mounted && value != null && value.isNotEmpty) {
                    setState(() => _value = value);
                  }
                }),
                child: Text(
                  isFree ? 'View ${widget.label}' : 'Reveal — $price',
                ),
              ),
      ),
    );
  }
}

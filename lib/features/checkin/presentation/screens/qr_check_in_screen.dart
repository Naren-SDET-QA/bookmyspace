import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../check_in_providers.dart';

class QrCheckInScreen extends ConsumerStatefulWidget {
  const QrCheckInScreen({super.key});

  @override
  ConsumerState<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends ConsumerState<QrCheckInScreen> {
  final _code = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Venue QR check-in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter the booking ID from the customer digital pass. '
            'The server confirms eligibility; this screen never marks a booking paid.',
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.brand, width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 72, color: AppTheme.brand),
                    SizedBox(height: 8),
                    Text('Camera scan is optional on this device.'),
                    Text('Use the booking code field below.'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Booking ID / pass code',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.verified),
            label: Text(_busy ? 'Checking…' : 'Check in'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(checkInRepositoryProvider)
          .checkIn(code: code, method: 'code');
      setState(() {
        _message = result.alreadyCheckedIn
            ? 'Already checked in for ${result.bookingId}'
            : 'Checked in ${result.bookingId}';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

import 'package:flutter/material.dart';

import '../domain/booking_intent.dart';

/// Text fallback and confirmation surface for provider-neutral voice input.
/// A speech adapter can call [onTranscript] when microphone support is added;
/// no booking or payment is performed until the user explicitly confirms.
class VoiceBookingSheet extends StatefulWidget {
  const VoiceBookingSheet({super.key, required this.onConfirmed});
  final ValueChanged<BookingIntent> onConfirmed;

  @override
  State<VoiceBookingSheet> createState() => _VoiceBookingSheetState();
}

class _VoiceBookingSheetState extends State<VoiceBookingSheet> {
  final _controller = TextEditingController();
  BookingIntent? _intent;
  final _parser = const BookingIntentParser();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _interpret() =>
      setState(() => _intent = _parser.parse(_controller.text));

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ask BookMySpace', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Microphone access is optional. Type your request if voice is unavailable.',
        ),
        TextField(
          controller: _controller,
          maxLines: 2,
          onChanged: (_) => _intent = null,
          decoration: const InputDecoration(
            hintText:
                'e.g. function hall in Hyderabad for 200 people under 30000',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _interpret,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Interpret request'),
        ),
        if (_intent != null) ...[
          const SizedBox(height: 12),
          Text(
            'Interpreted request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            [
              _intent!.category,
              _intent!.location,
              _intent!.dateLabel,
              _intent!.guests == null ? null : '${_intent!.guests} guests',
              _intent!.budget == null ? null : 'budget ${_intent!.budget}',
            ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _intent!.hasSearchSignal
                ? () {
                    widget.onConfirmed(_intent!);
                    Navigator.pop(context);
                  }
                : null,
            child: const Text('Confirm and search'),
          ),
        ],
      ],
    ),
  );
}

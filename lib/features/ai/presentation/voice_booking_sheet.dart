import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modular/feature_id.dart';
import '../../../core/modular/feature_providers.dart';
import '../../../core/modular/plugins/voice_provider.dart';
import '../../booking/domain/configurable_booking.dart';
import '../../venues/presentation/category_configuration_providers.dart';
import '../domain/booking_intent.dart';
import '../domain/voice_locale.dart';

/// Typed or spoken confirmation surface for provider-neutral voice input.
/// No booking or payment is performed until the user explicitly confirms.
class VoiceBookingSheet extends ConsumerStatefulWidget {
  const VoiceBookingSheet({super.key, required this.onConfirmed});
  final ValueChanged<BookingIntent> onConfirmed;

  @override
  ConsumerState<VoiceBookingSheet> createState() => _VoiceBookingSheetState();
}

class _VoiceBookingSheetState extends ConsumerState<VoiceBookingSheet> {
  final _controller = TextEditingController();
  BookingIntent? _intent;
  final _parser = const BookingIntentParser();
  bool _listening = false;
  String? _voiceError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _interpret() =>
      setState(() => _intent = _parser.parse(_controller.text));

  List<BookingFieldSpec> _bookingFields(BookingIntent intent) {
    final matched = ref
        .read(categoryAliasIndexProvider)
        .match(
          [intent.category, _controller.text].whereType<String>().join(' '),
        );
    return ConfigurableBookingFields.resolve(
      config: matched,
      sectionId: intent.category,
      registry: ref.read(featureRegistryProvider),
    );
  }

  VoiceProvider? _voicePlugin() {
    return resolvedVoiceProvider(ref.read(providerRegistryProvider));
  }

  Future<void> _toggleVoice() async {
    final voice = _voicePlugin();
    if (voice == null) {
      setState(() {
        _voiceError =
            'Voice is unavailable on this device. Type your request instead.';
      });
      return;
    }
    if (_listening) {
      await voice.stop();
      setState(() => _listening = false);
      return;
    }
    try {
      await voice.ensureInitialized();
    } catch (_) {
      setState(() {
        _voiceError =
            'Voice is unavailable on this device. Type your request instead.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _listening = true;
      _voiceError = null;
    });
    await voice.listen(
      localeId: VoiceLocale.speechId(Localizations.localeOf(context)),
      onResult: (words) {
        setState(() {
          _controller.text = words;
          _intent = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceEnabled = ref
        .watch(featureRegistryProvider)
        .isExposed(FeatureId.voice);
    final intent = _intent;
    final bookingFields = intent == null
        ? const <BookingFieldSpec>[]
        : _bookingFields(intent);
    final missingFields = intent?.missingRequiredFor(bookingFields) ?? const [];
    return Padding(
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
          Text(
            'Ask BookMySpace',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Speak in English, Telugu or Hindi, or type if the microphone is unavailable.',
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _interpret,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Interpret request'),
                ),
              ),
              if (voiceEnabled) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _toggleVoice,
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
              ],
            ],
          ),
          if (_voiceError != null) ...[
            const SizedBox(height: 8),
            Text(_voiceError!),
          ],
          if (intent != null) ...[
            const SizedBox(height: 12),
            Text(
              'Interpreted request',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              [
                intent.category,
                intent.location,
                intent.dateLabel,
                intent.guests == null ? null : '${intent.guests} guests',
                intent.budget == null ? null : 'budget ${intent.budget}',
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            ),
            if (missingFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Need: ${missingFields.join(', ')}'),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed:
                  intent.isCompleteForBookingWith(bookingFields) ||
                      (!intent.wantsBooking && intent.hasSearchSignal)
                  ? () {
                      widget.onConfirmed(intent);
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
}

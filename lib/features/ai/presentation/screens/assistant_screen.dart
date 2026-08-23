import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/modular/feature_id.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/plugins/voice_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../search/domain/ai_search_intent.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../domain/booking_intent.dart';
import '../../domain/voice_locale.dart';
import '../voice_booking_sheet.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  String? _heard;
  bool _listening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Describe the space you need in English, Telugu or Hindi. '
            'Search uses aliases from category configuration. '
            'Availability and price stay server-authoritative.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g. marriage hall in Vijayawada for 300 people',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ),
              if (ref.watch(featureRegistryProvider).isExposed(FeatureId.voice)) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _toggleVoice,
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
              ],
            ],
          ),
          if (_heard != null) ...[
            const SizedBox(height: 12),
            Text('Heard: $_heard'),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => VoiceBookingSheet(
                  onConfirmed: (intent) {
                    Navigator.pop(context);
                    _openFromBookingIntent(intent);
                  },
                ),
              );
            },
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Voice booking helper'),
          ),
        ],
      ),
    );
  }

  VoiceProvider? _voicePlugin() {
    return resolvedVoiceProvider(ref.read(providerRegistryProvider));
  }

  Future<void> _toggleVoice() async {
    final voice = _voicePlugin();
    if (voice == null) return;
    if (_listening) {
      await voice.stop();
      setState(() => _listening = false);
      return;
    }
    try {
      await voice.ensureInitialized();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await voice.listen(
      localeId: VoiceLocale.speechId(Localizations.localeOf(context)),
      onResult: (words) {
        setState(() {
          _heard = words;
          _controller.text = words;
        });
      },
    );
  }

  void _search() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final index = ref.read(categoryAliasIndexProvider);
    final matched = index.match(text);
    final intent = AiSearchIntent.parse(text, aliases: index);
    context.push(
      AppRoutes.search,
      extra: {
        'query': text,
        'section': matched?.sectionId ?? intent.section?.id,
        'category': matched?.slug ?? intent.categorySlug,
        'intent': intent,
      },
    );
  }

  void _openFromBookingIntent(BookingIntent intent) {
    final query = [
      intent.category,
      if (intent.location != null) 'in ${intent.location}',
      if (intent.guests != null) '${intent.guests} guests',
    ].whereType<String>().join(' ');
    context.push(
      AppRoutes.search,
      extra: {
        'query': query,
        'section': intent.category,
      },
    );
  }
}

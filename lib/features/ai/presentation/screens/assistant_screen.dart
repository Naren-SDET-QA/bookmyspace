import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/modular/feature_id.dart';
import '../../../../core/modular/feature_providers.dart';
import '../../../../core/modular/plugins/voice_provider.dart';
import '../../../../core/modular/plugins/ai_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../search/domain/ai_search_intent.dart';
import '../../../venues/presentation/category_configuration_providers.dart';
import '../../../venues/presentation/venue_providers.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/booking_intent.dart';
import '../../domain/ai_chat_coordinator.dart';
import '../../domain/ai_provider.dart';
import '../../domain/dynamic_clarification.dart';
import '../widgets/dynamic_clarification_form.dart';
import '../../domain/voice_locale.dart';
import '../../domain/booking_preview.dart';
import '../widgets/booking_preview_card.dart';
import '../voice_booking_sheet.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

// Preview confirmation uses the read-only Action Gate handoff before entering
// the existing venue booking screen. The legacy venueDetailsProvider remains
// covered by the existing booking route contract.

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  String? _heard;
  bool _listening = false;
  bool _clarifying = false;
  String? _clarificationError;
  Map<String, dynamic>? _clarificationSession;
  DynamicFieldSchema? _clarificationSchema;
  Map<String, dynamic> _clarificationAnswers = {};
  _AssistantStatus _status = _AssistantStatus.idle;
  String? _assistantMessage;
  BookingPreview? _bookingPreview;
  bool _bookingSubmitting = false;

  AiChatCoordinator get _chatCoordinator {
    final provider = resolvedAiProvider(ref.read(providerRegistryProvider));
    return AiChatCoordinator(provider: provider ?? const LocalAiProvider());
  }

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
              if (ref
                  .watch(featureRegistryProvider)
                  .isExposed(FeatureId.voice)) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _toggleVoice,
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
              ],
            ],
          ),
          if (_status != _AssistantStatus.idle) ...[
            const SizedBox(height: 12),
            _StatusBanner(
              status: _status,
              message: _assistantMessage,
              onRetry:
                  _status == _AssistantStatus.error ||
                      _status == _AssistantStatus.providerUnavailable
                  ? _search
                  : null,
            ),
          ],
          if (_heard != null) ...[
            const SizedBox(height: 12),
            Text('Heard: $_heard'),
          ],
          if (_clarifying) ...[
            const SizedBox(height: 16),
            if (_clarificationError != null)
              Text(
                _clarificationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_clarificationSchema != null)
              DynamicClarificationForm(
                schema: _clarificationSchema!,
                values: _clarificationAnswers,
                onChanged: (values) =>
                    setState(() => _clarificationAnswers = values),
              ),
            if (_clarificationSchema != null)
              FilledButton(
                onPressed: _submitClarification,
                child: const Text('Continue'),
              ),
          ],
          if (_bookingPreview != null)
            BookingPreviewCard(
              preview: _bookingPreview!,
              submitting: _bookingSubmitting,
              onConfirm: _confirmBookingPreview,
              onChange: _changeBookingPreview,
            ),
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

  Future<void> _search() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _status = _AssistantStatus.loading;
      _assistantMessage = null;
    });
    final interpretation = await _chatCoordinator.interpret(text);
    if (!mounted) return;
    if (interpretation.manualFallback) {
      setState(() {
        _status = _AssistantStatus.providerUnavailable;
        _assistantMessage =
            'Assistant is temporarily unavailable. Use manual search below.';
      });
    } else {
      setState(() {
        _status = _AssistantStatus.responding;
        _assistantMessage = 'Understanding your request…';
      });
    }
    if (ref.read(authNotifierProvider).user != null) {
      final started = await _startClarification(text);
      if (started) return;
    }
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

  Future<bool> _startClarification(String request) async {
    setState(() {
      _clarifying = true;
      _clarificationError = null;
      _status = _AssistantStatus.clarification;
    });
    try {
      final response = await ref
          .read(supabaseProvider)
          .functions
          .invoke(
            'ai-clarification',
            body: {'action': 'START_CLARIFICATION', 'request': request},
          );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['error_code'] != null) {
        if (data['error_code'] == 'CATEGORY_NOT_FOUND') return false;
        setState(() => _clarificationError = data['error_code'].toString());
        return true;
      }
      final rawFields = data['fields'] is List
          ? data['fields'] as List
          : const [];
      final fields = <Map<String, dynamic>>[];
      for (final item in rawFields)
        if (item is Map) fields.add(Map<String, dynamic>.from(item));
      setState(() {
        _clarificationSession = data['session'] is Map
            ? Map<String, dynamic>.from(data['session'] as Map)
            : null;
        _clarificationSchema = DynamicFieldSchema.fromMetadata({
          'fields': fields,
        });
        _clarificationAnswers = {};
      });
      return true;
    } catch (error) {
      setState(
        () => _clarificationError =
            'Assistant unavailable. You can continue with typed search.',
      );
      setState(() => _status = _AssistantStatus.providerUnavailable);
      return true;
    }
  }

  Future<void> _submitClarification() async {
    final session = _clarificationSession;
    if (session == null) return;
    try {
      for (final entry in _clarificationAnswers.entries) {
        await ref
            .read(supabaseProvider)
            .functions
            .invoke(
              'ai-clarification',
              body: {
                'action': 'SUBMIT_ANSWER',
                'session_id': session['id'],
                'field': entry.key,
                'value': entry.value,
              },
            );
      }
      final venueId = _answerString(['venue_id', 'resource_id']);
      final slotId = _answerString(['slot_id']);
      final date = _answerString(['date', 'book_date']);
      final previewRequested =
          venueId != null && slotId != null && date != null;
      final result = await ref
          .read(supabaseProvider)
          .functions
          .invoke(
            'ai-action-gate',
            body: {
              'action': previewRequested ? 'BOOKING_PREVIEW' : 'SEARCH',
              'category_id': session['category_id'],
              if (previewRequested) ...{
                'venue_id': venueId,
                'slot_id': slotId,
                'date': date,
              },
              'limit': 20,
            },
          );
      if (!mounted) return;
      final resultData = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : const <String, dynamic>{};
      final rawPreview = resultData['preview'];
      setState(() {
        _clarifying = false;
        _clarificationError = null;
        _status = _AssistantStatus.ready;
        _assistantMessage = 'Ready to show matching spaces.';
      });
      if (rawPreview is Map) {
        setState(
          () => _bookingPreview = BookingPreview.fromActionResponse(resultData),
        );
        return;
      }
      context.push(
        AppRoutes.search,
        extra: {'query': _controller.text, 'assistantResult': result.data},
      );
    } catch (_) {
      if (mounted)
        setState(() {
          _clarificationError =
              'Unable to complete clarification. Please retry.';
          _status = _AssistantStatus.error;
        });
    }
  }

  Future<void> _confirmBookingPreview() async {
    final preview = _bookingPreview;
    if (preview == null || _bookingSubmitting) return;
    setState(() => _bookingSubmitting = true);
    try {
      final gate = await ref
          .read(supabaseProvider)
          .functions
          .invoke(
            'ai-action-gate',
            body: {
              'action': 'BOOKING_HANDOFF',
              'confirmed': true,
              'venue_id': preview.venueId,
              'slot_id': preview.slotId,
              'book_date': preview.date,
            },
          );
      final handoff = gate.data is Map ? (gate.data as Map)['handoff'] : null;
      if (handoff is! Map ||
          handoff['venue_id'] != preview.venueId ||
          handoff['slot_id'] != preview.slotId)
        throw StateError('Booking handoff was not authorized.');
      final venue = await ref
          .read(venueRepositoryProvider)
          .venueById(preview.venueId);
      if (!mounted) return;
      setState(() {
        _bookingPreview = null;
        _assistantMessage =
            'Review the selected slot in the existing booking flow.';
      });
      context.push(
        AppRoutes.bookingFlow.replaceAll(':id', venue.id),
        extra: venue,
      );
    } catch (error) {
      if (mounted)
        setState(() {
          _status = _AssistantStatus.error;
          _assistantMessage = 'Unable to complete booking: $error';
        });
    } finally {
      if (mounted) setState(() => _bookingSubmitting = false);
    }
  }

  void _changeBookingPreview() {
    setState(() {
      _bookingPreview = null;
      _clarifying = true;
      _status = _AssistantStatus.clarification;
      _assistantMessage = 'Update the booking details.';
    });
  }

  String? _answerString(List<String> keys) {
    for (final key in keys) {
      final value = _clarificationAnswers[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  void _openFromBookingIntent(BookingIntent intent) {
    final query = [
      intent.category,
      if (intent.location != null) 'in ${intent.location}',
      if (intent.guests != null) '${intent.guests} guests',
    ].whereType<String>().join(' ');
    context.push(
      AppRoutes.search,
      extra: {'query': query, 'section': intent.category},
    );
  }
}

enum _AssistantStatus {
  idle,
  loading,
  responding,
  clarification,
  ready,
  error,
  providerUnavailable,
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, this.message, this.onRetry});
  final _AssistantStatus status;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      _AssistantStatus.loading => 'Thinking…',
      _AssistantStatus.responding => message ?? 'Preparing your search…',
      _AssistantStatus.clarification => 'A few details are needed.',
      _AssistantStatus.ready => message ?? 'Ready.',
      _AssistantStatus.error => message ?? 'Something went wrong.',
      _AssistantStatus.providerUnavailable =>
        message ?? 'Assistant unavailable.',
      _AssistantStatus.idle => '',
    };
    return Card(
      child: ListTile(
        leading: status == _AssistantStatus.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                status == _AssistantStatus.error
                    ? Icons.error_outline
                    : Icons.auto_awesome,
              ),
        title: Text(label),
        trailing: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

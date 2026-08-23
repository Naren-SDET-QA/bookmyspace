import 'package:speech_to_text/speech_to_text.dart';

import 'voice_provider.dart';

/// Host for the existing `speech_to_text` engine. Constructed only when voice
/// is resolved; [SpeechToText] is created on first [ensureInitialized]/[listen].
class SpeechVoicePlugin implements VoiceProvider {
  SpeechVoicePlugin({SpeechToText Function()? create})
    : _create = create ?? SpeechToText.new;

  final SpeechToText Function() _create;
  SpeechToText? _engine;
  bool _ready = false;

  SpeechToText get engine => _engine ??= _create();

  @override
  String get id => 'speech_to_text';

  @override
  bool get initialized => _ready;

  @override
  Future<void> ensureInitialized() async {
    final available = await engine.initialize();
    if (!available) {
      throw StateError('speech unavailable');
    }
    _ready = true;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words) onResult,
  }) {
    return engine.listen(
      localeId: localeId,
      onResult: (result) => onResult(result.recognizedWords),
    );
  }

  @override
  Future<void> stop() async {
    await _engine?.stop();
  }

  @override
  Future<void> dispose() async {
    await _engine?.stop();
    _engine = null;
    _ready = false;
  }
}

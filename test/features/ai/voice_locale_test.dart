import 'package:bookmyspace/features/ai/domain/voice_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps English, Telugu and Hindi onto speech recognizer locales', () {
    expect(VoiceLocale.speechId(const Locale('en')), 'en_IN');
    expect(VoiceLocale.speechId(const Locale('te')), 'te_IN');
    expect(VoiceLocale.speechId(const Locale('hi')), 'hi_IN');
    expect(VoiceLocale.speechId(const Locale('fr')), 'en_IN');
  });

  test('maps restored locales onto speech recognizer ids', () {
    expect(VoiceLocale.speechId(const Locale('ta')), 'ta_IN');
    expect(VoiceLocale.speechId(const Locale('kn')), 'kn_IN');
    expect(VoiceLocale.speechId(const Locale('mr')), 'mr_IN');
    expect(VoiceLocale.speechId(const Locale('bn')), 'bn_IN');
    expect(VoiceLocale.speechId(const Locale('gu')), 'gu_IN');
    expect(VoiceLocale.speechId(const Locale('ml')), 'ml_IN');
    expect(VoiceLocale.speechId(const Locale('es')), 'es_ES');
  });
}

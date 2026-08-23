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
}

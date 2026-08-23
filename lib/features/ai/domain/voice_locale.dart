import 'package:flutter/widgets.dart';

/// Maps app locales onto on-device speech recognizer ids.
/// Falls back to English India when the locale is unsupported.
class VoiceLocale {
  const VoiceLocale._();

  static String speechId(Locale locale) {
    return switch (locale.languageCode) {
      'te' => 'te_IN',
      'hi' => 'hi_IN',
      _ => 'en_IN',
    };
  }
}

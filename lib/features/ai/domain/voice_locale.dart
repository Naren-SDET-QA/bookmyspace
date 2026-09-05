import 'package:flutter/widgets.dart';

/// Maps app locales onto on-device speech recognizer ids.
/// Falls back to English India when the locale is unsupported.
class VoiceLocale {
  const VoiceLocale._();

  static String speechId(Locale locale) {
    return switch (locale.languageCode) {
      'te' => 'te_IN',
      'hi' => 'hi_IN',
      'ta' => 'ta_IN',
      'kn' => 'kn_IN',
      'mr' => 'mr_IN',
      'bn' => 'bn_IN',
      'gu' => 'gu_IN',
      'ml' => 'ml_IN',
      'es' => 'es_ES',
      _ => 'en_IN',
    };
  }
}

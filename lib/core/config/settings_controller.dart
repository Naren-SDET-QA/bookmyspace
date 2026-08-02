import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod/riverpod.dart';

import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';

/// Persisted user preferences backed by [FlutterSecureStorage].
class Preferences {
  Preferences(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final preferencesProvider = Provider<Preferences>((ref) {
  return Preferences(ref.watch(secureStorageProvider));
});

/// Theme mode controller (system / light / dark), persisted.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = ref.read(preferencesProvider);
    final saved = await prefs.read(AppConstants.prefsThemeModeKey);
    if (saved != null && !_loaded) {
      _loaded = true;
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  bool _loaded = false;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsThemeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Locale controller (en / te), persisted.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return AppLocalizations.supportedLocales.first;
  }

  bool _loaded = false;

  Future<void> _load() async {
    final prefs = ref.read(preferencesProvider);
    final saved = await prefs.read(AppConstants.prefsLocaleKey);
    if (saved != null && !_loaded) {
      _loaded = true;
      state = AppLocalizations.supportedLocales.firstWhere(
        (l) => l.languageCode == saved,
        orElse: () => AppLocalizations.supportedLocales.first,
      );
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsLocaleKey, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Tracks whether onboarding has been completed.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = ref.read(preferencesProvider);
    final done = await prefs.read(AppConstants.prefsOnboardingDoneKey);
    if (done == 'true') state = true;
  }

  Future<void> complete() async {
    state = true;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsOnboardingDoneKey, 'true');
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

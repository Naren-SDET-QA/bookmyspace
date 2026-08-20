import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
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

enum ThemePalette {
  indigo(0xFF3F51B5, 'Indigo'),
  ocean(0xFF0077B6, 'Ocean'),
  forest(0xFF2E7D32, 'Forest'),
  emerald(0xFF00897B, 'Emerald'),
  sunset(0xFFE65100, 'Sunset'),
  rose(0xFFC2185B, 'Rose'),
  plum(0xFF6A1B9A, 'Plum'),
  amber(0xFFFF8F00, 'Amber'),
  teal(0xFF00695C, 'Teal'),
  slate(0xFF455A64, 'Slate'),
  coral(0xFFD84315, 'Coral'),
  sky(0xFF1565C0, 'Sky');

  const ThemePalette(this.value, this.label);
  final int value;
  final String label;
  Color get color => Color(value);
}

class ThemePaletteNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return ThemePalette.indigo.name;
  }

  Future<void> _load() async {
    final saved = await ref
        .read(preferencesProvider)
        .read(AppConstants.prefsThemePaletteKey);
    if (saved != null &&
        (ThemePalette.values.any((p) => p.name == saved) ||
            _parseHex(saved) != null))
      state = saved;
  }

  Future<void> setPalette(ThemePalette palette) async {
    state = palette.name;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsThemePaletteKey, palette.name);
  }

  Future<bool> setCustomHex(String value) async {
    final normalized = value.trim().replaceFirst('#', '');
    final color = _parseHex(normalized);
    if (color == null) return false;
    state = normalized.toUpperCase();
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsThemePaletteKey, state);
    return true;
  }

  Color get color => themePaletteColor(state);
}

Color? _parseHex(String value) {
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(int.parse('FF$value', radix: 16));
}

final themePaletteProvider = NotifierProvider<ThemePaletteNotifier, String>(
  ThemePaletteNotifier.new,
);

Color themePaletteColor(String value) =>
    _parseHex(value) ??
    ThemePalette.values
        .firstWhere((p) => p.name == value, orElse: () => ThemePalette.indigo)
        .color;

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

enum BookingMode { normal, quick }

class SimpleModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final saved = await ref
        .read(preferencesProvider)
        .read(AppConstants.prefsSimpleModeKey);
    if (saved != null) state = saved == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsSimpleModeKey, '$enabled');
  }
}

final simpleModeProvider = NotifierProvider<SimpleModeNotifier, bool>(
  SimpleModeNotifier.new,
);

class BookingModeNotifier extends Notifier<BookingMode> {
  @override
  BookingMode build() {
    _load();
    return BookingMode.normal;
  }

  Future<void> _load() async {
    final saved = await ref
        .read(preferencesProvider)
        .read(AppConstants.prefsBookingModeKey);
    if (saved != null) {
      state = BookingMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => BookingMode.normal,
      );
    }
  }

  Future<void> setMode(BookingMode mode) async {
    state = mode;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsBookingModeKey, mode.name);
  }
}

final bookingModeProvider = NotifierProvider<BookingModeNotifier, BookingMode>(
  BookingModeNotifier.new,
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

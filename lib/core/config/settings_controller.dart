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

enum ThemePalette {
  indigo(0xFF4F46E5, 'Indigo', 'Default BookMySpace brand'),
  royalPurple(0xFF7C3AED, 'Royal Purple', 'Majestic regal purple'),
  electricTeal(0xFF00C9A7, 'Electric Teal', 'Sleek minty teal'),
  midnightNavy(0xFF2563EB, 'Midnight Navy', 'High-contrast sapphire'),
  emeraldLuxury(0xFF059669, 'Emerald Garden', 'Sophisticated emerald'),
  crimsonPassion(0xFFE11D48, 'Crimson Passion', 'Vibrant ruby red'),
  sunsetAmber(0xFFF59E0B, 'Sunset Amber', 'Warm saffron gold'),
  sapphireResort(0xFF0284C7, 'Sapphire Ocean', 'Refreshing ocean blue'),
  roseGold(0xFFDB2777, 'Rose Gold', 'Chic magenta blush'),
  cyberNeon(0xFF8B5CF6, 'Cyber Violet', 'Futuristic violet'),
  forestCanopy(0xFF166534, 'Forest Canopy', 'Deep forest green'),
  nordicSlate(0xFF475569, 'Nordic Slate', 'Professional slate grey');

  const ThemePalette(this.value, this.label, this.description);
  final int value;
  final String label;
  final String description;
  Color get color => Color(value);

  static const defaultPalette = indigo;

  static ThemePalette? byName(String value) {
    for (final palette in values) {
      if (palette.name == value) return palette;
    }
    return null;
  }
}

class ThemePaletteNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return ThemePalette.defaultPalette.name;
  }

  bool _loaded = false;

  Future<void> _load() async {
    final saved = await ref
        .read(preferencesProvider)
        .read(AppConstants.prefsThemePaletteKey);
    if (saved == null || _loaded) return;
    _loaded = true;
    if (ThemePalette.byName(saved) != null || parseThemeHex(saved) != null) {
      state = saved.startsWith('#') ? saved.substring(1).toUpperCase() : saved;
    }
  }

  Future<void> setPalette(ThemePalette palette) async {
    _loaded = true;
    state = palette.name;
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsThemePaletteKey, palette.name);
  }

  Future<bool> setCustomHex(String value) async {
    final color = parseThemeHex(value);
    if (color == null) return false;
    var cleaned = value.trim();
    if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
    _loaded = true;
    state = cleaned.toUpperCase();
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsThemePaletteKey, state);
    return true;
  }

  Future<void> resetToDefault() async {
    await setPalette(ThemePalette.defaultPalette);
  }

  Color get color => themePaletteColor(state);
}

/// Parses `#RRGGBB`, `RRGGBB`, or 8-digit ARGB. Returns null when invalid.
Color? parseThemeHex(String value) {
  var cleaned = value.trim();
  if (cleaned.startsWith('#')) cleaned = cleaned.substring(1);
  if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned)) {
    return Color(int.parse(cleaned, radix: 16));
  }
  return null;
}

final themePaletteProvider = NotifierProvider<ThemePaletteNotifier, String>(
  ThemePaletteNotifier.new,
);

Color themePaletteColor(String value) =>
    parseThemeHex(value) ??
    (ThemePalette.byName(value) ?? ThemePalette.defaultPalette).color;

/// Locale controller. Persisted language code; unknown values fall back to English.
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
      state = AppLocalizations.resolve(Locale(saved));
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = AppLocalizations.resolve(locale);
    await ref
        .read(preferencesProvider)
        .write(AppConstants.prefsLocaleKey, state.languageCode);
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

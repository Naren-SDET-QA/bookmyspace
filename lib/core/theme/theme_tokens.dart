import 'package:flutter/material.dart';

/// Central color tokens. Screens should read [ThemeData.colorScheme], not copy palettes.
///
/// [ThemeTokens.colorSchemeFor] is a faithful Dart port of the Android Native
/// app's `generateBookMySpaceColorScheme(seedColor, isDark)` (see
/// `ui/theme/Theme.kt` in the native BookMySpace repo). It replaces the
/// generic Material 3 `ColorScheme.fromSeed` tonal-palette derivation with the
/// same hue/saturation-driven role formulas the native app uses, so that
/// switching a theme preset/seed produces the same look on both platforms.
class ThemeTokens {
  const ThemeTokens({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.onSurface,
  });

  final Color primary;
  final Color secondary;
  final Color surface;
  final Color onSurface;

  factory ThemeTokens.fromSeed(
    Color seed, {
    Brightness brightness = Brightness.light,
    Color? secondary,
  }) {
    final scheme = ThemeTokens.colorSchemeFor(seed, brightness);
    return ThemeTokens(
      primary: scheme.primary,
      secondary: secondary ?? scheme.secondary,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
    );
  }

  /// Builds a full [ColorScheme] using the native app's custom HSL-based
  /// palette algorithm instead of Material 3's generic seeded tonal palette.
  ///
  /// Mirrors `generateBookMySpaceColorScheme` in the native `Theme.kt`
  /// role-for-role. `hslToColor`/`toHsl` there map directly onto Flutter's
  /// built-in [HSLColor]; `calculateLuminance` maps onto [Color.computeLuminance].
  static ColorScheme colorSchemeFor(Color seed, Brightness brightness) {
    final seedHsl = HSLColor.fromColor(seed);
    final hue = seedHsl.hue;
    final sat = seedHsl.saturation.clamp(0.20, 0.95);
    final secHue = (hue + 30) % 360;
    final tertHue = (hue + 140) % 360;

    Color hslToColor(double h, double s, double l) =>
        HSLColor.fromAHSL(1.0, h % 360, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0))
            .toColor();

    const white = Colors.white;

    if (brightness == Brightness.light) {
      final primary = hslToColor(hue, sat, 0.38);
      final onPrimary = primary.computeLuminance() > 0.45
          ? const Color(0xFF0F172A)
          : white;
      return ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: hslToColor(hue, sat * 0.35, 0.92),
        onPrimaryContainer: hslToColor(hue, sat * 0.90, 0.18),
        secondary: hslToColor(secHue, sat * 0.65, 0.42),
        onSecondary: white,
        secondaryContainer: hslToColor(secHue, sat * 0.30, 0.91),
        onSecondaryContainer: hslToColor(secHue, sat * 0.85, 0.20),
        tertiary: hslToColor(tertHue, sat * 0.75, 0.42),
        onTertiary: white,
        tertiaryContainer: hslToColor(tertHue, sat * 0.30, 0.92),
        onTertiaryContainer: hslToColor(tertHue, sat * 0.85, 0.18),
        error: const Color(0xFFDC2626),
        onError: white,
        errorContainer: const Color(0xFFFEE2E2),
        onErrorContainer: const Color(0xFF991B1B),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        onSurfaceVariant: const Color(0xFF334155),
        outline: const Color(0xFFCBD5E1),
        outlineVariant: const Color(0xFFE2E8F0),
      );
    }

    final primary = hslToColor(hue, sat * 0.85, 0.62);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: const Color(0xFF08101D),
      primaryContainer: hslToColor(hue, sat * 0.60, 0.22),
      onPrimaryContainer: hslToColor(hue, sat * 0.50, 0.88),
      secondary: hslToColor(secHue, sat * 0.75, 0.60),
      onSecondary: const Color(0xFF08101D),
      secondaryContainer: hslToColor(secHue, sat * 0.55, 0.20),
      onSecondaryContainer: hslToColor(secHue, sat * 0.50, 0.88),
      tertiary: hslToColor(tertHue, sat * 0.80, 0.65),
      onTertiary: const Color(0xFF08101D),
      tertiaryContainer: hslToColor(tertHue, sat * 0.55, 0.20),
      onTertiaryContainer: hslToColor(tertHue, sat * 0.50, 0.88),
      error: const Color(0xFFEF4444),
      onError: white,
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFEE2E2),
      surface: const Color(0xFF101B2B),
      onSurface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: const Color(0xFF19273C),
      onSurfaceVariant: const Color(0xFFCBD5E1),
      outline: const Color(0xFF475569),
      outlineVariant: const Color(0xFF334155),
    );
  }
}

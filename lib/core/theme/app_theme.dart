import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Centralised Material 3 theme for BookMySpace.
///
/// Supports light and dark mode using the native BookMySpace visual language.
class AppTheme {
  AppTheme._();

  /// Brand colours exposed for use across widgets.
  static const Color brand = Color(0xFF4F46E5);
  static const Color brandLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFFFF6B4A);
  static const Color _surfaceLight = Color(0xFFF8FAFC);
  static const Color _surfaceDark = Color(0xFF081A2B);

  static ThemeData get light => lightFor(brand);

  static ThemeData get dark => darkFor(brand);

  static ThemeData lightFor(Color seed) => _base(Brightness.light, seed);
  static ThemeData darkFor(Color seed) => _base(Brightness.dark, seed);

  static ThemeData _base(Brightness brightness, Color seed) {
    final isLight = brightness == Brightness.light;
    // Native-parity palette: ports the Android Native app's custom HSL-based
    // `generateBookMySpaceColorScheme` instead of Material 3's generic
    // seeded tonal palette (see ThemeTokens.colorSchemeFor).
    final scheme = ThemeTokens.colorSchemeFor(seed, brightness);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? _surfaceLight : _surfaceDark,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isLight ? _surfaceLight : _surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : const Color(0xFF102A43),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeColor {
  violet('Violet', Color(0xFF6C3DF4)),
  indigo('Indigo', Color(0xFF4F46E5)),
  teal('Teal', Color(0xFF0D9488)),
  rose('Rose', Color(0xFFE11D48));

  const AppThemeColor(this.label, this.color);

  final String label;
  final Color color;
}

/// Centralised Material 3 theme for BookMySpace.
///
/// Mirrors the purple/indigo visual language of the approved prototype.
class AppTheme {
  AppTheme._();

  /// Brand colours exposed for use across widgets.
  static const Color brand = Color(0xFF6C3DF4);
  static const Color brandLight = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF4F46E5);
  static const Color ink = Color(0xFF17132B);
  static const Color muted = Color(0xFF6F6A8F);
  static const Color surfaceLight = Color(0xFFF4F2FB);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE9E6F5);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFE11D48);
  static const Color warning = Color(0xFFD97706);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), accent],
  );

  static const double pagePadding = 18;
  static const double cardRadius = 20;
  static const double controlRadius = 15;
  static const double compactRadius = 11;

  static const Color _surfaceDark = Color(0xFF17132B);

  /// Platform emoji fonts so Latin brand fonts never swallow category glyphs.
  static const List<String> emojiFontFallbacks = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
    'Android Emoji',
    'Emoji',
  ];

  static ThemeData get light => lightFor(AppThemeColor.violet);

  static ThemeData get dark => darkFor(AppThemeColor.violet);

  static ThemeData lightFor(AppThemeColor choice) =>
      _base(Brightness.light, choice.color);

  static ThemeData darkFor(AppThemeColor choice) =>
      _base(Brightness.dark, choice.color);

  static TextTheme _textTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    // Widget tests disable runtime fetching (no network). Keep system fonts there
    // so Plus Jakarta is not requested; production still loads via google_fonts.
    final TextTheme themed = GoogleFonts.config.allowRuntimeFetching
        ? GoogleFonts.plusJakartaSansTextTheme(base)
        : base;
    TextStyle? withEmojiFallback(TextStyle? style) => style?.copyWith(
      fontFamilyFallback: emojiFontFallbacks,
    );
    return TextTheme(
      displayLarge: withEmojiFallback(themed.displayLarge),
      displayMedium: withEmojiFallback(themed.displayMedium),
      displaySmall: withEmojiFallback(themed.displaySmall),
      headlineLarge: withEmojiFallback(themed.headlineLarge),
      headlineMedium: withEmojiFallback(themed.headlineMedium),
      headlineSmall: withEmojiFallback(themed.headlineSmall),
      titleLarge: withEmojiFallback(themed.titleLarge),
      titleMedium: withEmojiFallback(themed.titleMedium),
      titleSmall: withEmojiFallback(themed.titleSmall),
      bodyLarge: withEmojiFallback(themed.bodyLarge),
      bodyMedium: withEmojiFallback(themed.bodyMedium),
      bodySmall: withEmojiFallback(themed.bodySmall),
      labelLarge: withEmojiFallback(themed.labelLarge),
      labelMedium: withEmojiFallback(themed.labelMedium),
      labelSmall: withEmojiFallback(themed.labelSmall),
    );
  }

  static ThemeData _base(Brightness brightness, Color seed) {
    final isLight = brightness == Brightness.light;
    // Keep exact brand violet (#6c3df4) — do not let fromSeed wash primary.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          primary: seed,
          secondary: seed,
          surface: isLight ? surfaceLight : _surfaceDark,
        ).copyWith(
          primary: seed,
          onPrimary: Colors.white,
          secondary: isLight ? accent : seed,
          surfaceTint: Colors.transparent,
        );

    final textTheme = _textTheme(brightness).apply(
      bodyColor: isLight ? ink : Colors.white,
      displayColor: isLight ? ink : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: isLight ? card : _surfaceDark,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: isLight ? line : scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          elevation: 4,
          shadowColor: seed.withValues(alpha: .30),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? card : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: isLight ? line : scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: isLight ? line : scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? card : scheme.surfaceContainerHighest,
        selectedColor: isLight ? ink : seed,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: isLight ? muted : scheme.onSurface,
          fontFamilyFallback: emojiFontFallbacks,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamilyFallback: emojiFontFallbacks,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: isLight ? line : scheme.outlineVariant),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? line : scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // Prototype `#nav` is 88px tall with a 44×27 selected pill.
        height: 88,
        backgroundColor: isLight
            ? Colors.white.withValues(alpha: 0.92)
            : _surfaceDark,
        indicatorColor: isLight
            ? const Color(0xFFEFE9FF)
            : seed.withValues(alpha: 0.18),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? seed
                : const Color(0xFFA29EC4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? seed
                : const Color(0xFFA29EC4),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? card : const Color(0xFF211C38),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: const Color(0xFFE3DFF2),
        dragHandleSize: const Size(42, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? card : const Color(0xFF211C38),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Shared motion tokens for consistent, restrained micro-interactions.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Subtle press scale for tappable cards.
  static const double cardPressScale = 0.98;
}

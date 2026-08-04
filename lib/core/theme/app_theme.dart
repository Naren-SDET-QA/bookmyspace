import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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

  static ThemeData get light => lightFor(AppThemeColor.violet);

  static ThemeData get dark => darkFor(AppThemeColor.violet);

  static ThemeData lightFor(AppThemeColor choice) =>
      _base(Brightness.light, choice.color);

  static ThemeData darkFor(AppThemeColor choice) =>
      _base(Brightness.dark, choice.color);

  static ThemeData _base(Brightness brightness, Color seed) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: isLight ? seed : Color.lerp(seed, Colors.white, .22)!,
      secondary: seed,
      surface: isLight ? surfaceLight : _surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Plus Jakarta Sans',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
        fontFamily: 'Plus Jakarta Sans',
        bodyColor: isLight ? ink : Colors.white,
        displayColor: isLight ? ink : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isLight ? .11 : .32),
        surfaceTintColor: Colors.transparent,
        color: isLight ? card : _surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: isLight ? line : scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          elevation: 2,
          shadowColor: scheme.primary.withValues(alpha: .32),
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
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isLight ? Colors.white : _surfaceDark,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? card : const Color(0xFF211C38),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
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
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
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

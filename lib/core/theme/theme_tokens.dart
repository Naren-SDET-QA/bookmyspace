import 'package:flutter/material.dart';

/// Central color tokens. Screens should read [ThemeData.colorScheme], not copy palettes.
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
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    return ThemeTokens(
      primary: isLight ? seed : scheme.primary,
      secondary: secondary ?? scheme.secondary,
      surface: isLight ? const Color(0xFFF7F7FA) : const Color(0xFF131318),
      onSurface: scheme.onSurface,
    );
  }
}

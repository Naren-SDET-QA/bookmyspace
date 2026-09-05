import 'package:flutter/material.dart';

class AdminSettings {
  const AdminSettings({
    this.home = const {},
    this.theme = const {},
    this.modules = const {},
  });
  final Map<String, dynamic> home;
  final Map<String, dynamic> theme;
  final Map<String, dynamic> modules;

  static const defaults = AdminSettings(
    home: {
      'search_placeholder': 'Search hotels, PGs, venues...',
      'hero_title': 'Find your perfect space',
      'hero_subtitle': 'Discover and book spaces that fit your needs.',
      'primary_booking_button_text': 'Book Now',
      'home_banner_visible': true,
      'search_banner_visible': true,
    },
    theme: {
      'primary_color': '#3F51B5',
      'accent_color': '#757DE8',
      'banner_background': '#EEF1FF',
      'banner_text_color': '#17204A',
    },
  );

  AdminSettings copyWith({
    Map<String, dynamic>? home,
    Map<String, dynamic>? theme,
    Map<String, dynamic>? modules,
  }) => AdminSettings(
    home: home ?? this.home,
    theme: theme ?? this.theme,
    modules: modules ?? this.modules,
  );

  static bool validHex(String value) =>
      RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value.trim());
  static String text(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  static bool flag(Object? value, {bool fallback = false}) =>
      value is bool ? value : fallback;
  static Color color(Object? value, Color fallback) {
    final raw = value?.toString() ?? '';
    if (!validHex(raw)) return fallback;
    return Color(
      int.parse(raw.substring(1), radix: 16) |
          (raw.length == 7 ? 0xFF000000 : 0),
    );
  }
}

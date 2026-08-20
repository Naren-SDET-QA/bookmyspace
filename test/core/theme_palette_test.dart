import 'package:bookmyspace/core/config/settings_controller.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides twelve curated palettes', () {
    expect(ThemePalette.values, hasLength(12));
    expect(
      ThemePalette.values.map((p) => p.color.value).toSet(),
      hasLength(12),
    );
  });

  test('invalid custom color safely falls back to default palette', () {
    expect(themePaletteColor('not-a-color'), ThemePalette.indigo.color);
    expect(themePaletteColor('12345'), ThemePalette.indigo.color);
    expect(themePaletteColor('GGGGGG'), ThemePalette.indigo.color);
  });

  test('selected palette is applied to light and dark themes', () {
    final theme = themePaletteColor(ThemePalette.forest.name);
    expect(AppTheme.lightFor(theme).colorScheme.primary, isNotNull);
    expect(AppTheme.darkFor(theme).colorScheme.primary, isNotNull);
  });
}

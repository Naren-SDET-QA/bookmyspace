import 'package:bookmyspace/core/config/settings_controller.dart';
import 'package:bookmyspace/core/constants/app_constants.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/features/settings/presentation/screens/theme_customizer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferences extends Preferences {
  _MemoryPreferences() : super(const FlutterSecureStorage());

  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  test('default theme is indigo and matches the current brand', () {
    expect(ThemePalette.values, hasLength(12));
    expect(ThemePalette.defaultPalette, ThemePalette.indigo);
    expect(ThemePalette.indigo.color, AppTheme.brand);
    expect(themePaletteColor('unknown'), ThemePalette.indigo.color);
    expect(
      AppTheme.light.colorScheme.primary,
      AppTheme.lightFor(AppTheme.brand).colorScheme.primary,
    );
  });

  test('legacy presets are available with unique seed colors', () {
    expect(
      ThemePalette.values.map((p) => p.name),
      containsAll([
        'indigo',
        'royalPurple',
        'electricTeal',
        'forestCanopy',
        'nordicSlate',
      ]),
    );
    expect(
      ThemePalette.values.map((p) => p.color.toARGB32()).toSet(),
      hasLength(12),
    );
  });

  test('invalid custom color safely falls back to default palette', () {
    expect(parseThemeHex('not-a-color'), isNull);
    expect(parseThemeHex('12345'), isNull);
    expect(parseThemeHex('#GGGGGG'), isNull);
    expect(parseThemeHex(''), isNull);
    expect(themePaletteColor('not-a-color'), ThemePalette.indigo.color);
    expect(themePaletteColor('12345'), ThemePalette.indigo.color);
    expect(themePaletteColor('GGGGGG'), ThemePalette.indigo.color);
  });

  test('valid hex codes parse with or without a hash', () {
    expect(parseThemeHex('#00C9A7'), isNotNull);
    expect(
      parseThemeHex('00c9a7')!.toARGB32(),
      parseThemeHex('#00C9A7')!.toARGB32(),
    );
    expect(parseThemeHex('FF00C9A7'), isNotNull);
  });

  test('selected palette is applied to light and dark themes', () {
    final seed = themePaletteColor(ThemePalette.forestCanopy.name);
    expect(AppTheme.lightFor(seed).colorScheme.primary, isNotNull);
    expect(AppTheme.darkFor(seed).colorScheme.primary, isNotNull);
    expect(
      AppTheme.lightFor(seed).colorScheme.primary,
      isNot(AppTheme.lightFor(AppTheme.brand).colorScheme.primary),
    );
  });

  test('preset selection and custom color persist and reload', () async {
    final prefs = _MemoryPreferences();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(themePaletteProvider), ThemePalette.indigo.name);

    await container
        .read(themePaletteProvider.notifier)
        .setPalette(ThemePalette.royalPurple);
    expect(container.read(themePaletteProvider), 'royalPurple');
    expect(prefs.values[AppConstants.prefsThemePaletteKey], 'royalPurple');

    final ok = await container
        .read(themePaletteProvider.notifier)
        .setCustomHex('#E11D48');
    expect(ok, isTrue);
    expect(container.read(themePaletteProvider), 'E11D48');
    expect(
      themePaletteColor(container.read(themePaletteProvider)).toARGB32(),
      0xFFE11D48,
    );

    final reloaded = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.read(themePaletteProvider), ThemePalette.indigo.name);
    await Future<void>.delayed(Duration.zero);
    expect(reloaded.read(themePaletteProvider), 'E11D48');
  });

  test('reset restores the default palette', () async {
    final prefs = _MemoryPreferences();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(themePaletteProvider.notifier)
        .setPalette(ThemePalette.crimsonPassion);
    await container.read(themePaletteProvider.notifier).resetToDefault();
    expect(container.read(themePaletteProvider), ThemePalette.indigo.name);
    expect(
      prefs.values[AppConstants.prefsThemePaletteKey],
      ThemePalette.indigo.name,
    );
  });

  test(
    'invalid custom hex is rejected and leaves the current palette',
    () async {
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(_MemoryPreferences()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(themePaletteProvider.notifier)
          .setPalette(ThemePalette.electricTeal);
      final rejected = await container
          .read(themePaletteProvider.notifier)
          .setCustomHex('not-a-color');
      expect(rejected, isFalse);
      expect(container.read(themePaletteProvider), 'electricTeal');
    },
  );

  testWidgets('customizer selects a preset, applies hex, and resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = _MemoryPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: ThemeCustomizerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme_customizer_screen')), findsOneWidget);
    expect(find.byKey(const Key('live_theme_preview_card')), findsOneWidget);
    expect(find.text('Indigo'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('custom_hex_text_field')),
      '#0284C7',
    );
    await tester.pump();
    expect(prefs.values[AppConstants.prefsThemePaletteKey], '0284C7');

    await tester.enterText(
      find.byKey(const Key('custom_hex_text_field')),
      'nope',
    );
    await tester.tap(find.byKey(const Key('theme_hex_apply')));
    await tester.pump();
    expect(
      find.text('Enter a valid 6-character hex code (e.g. #3F51B5)'),
      findsOneWidget,
    );
    expect(prefs.values[AppConstants.prefsThemePaletteKey], '0284C7');

    await tester.tap(find.byKey(const Key('theme_preset_royalPurple')));
    await tester.pumpAndSettle();
    expect(prefs.values[AppConstants.prefsThemePaletteKey], 'royalPurple');

    await tester.tap(find.byKey(const Key('theme_reset_button')));
    await tester.pumpAndSettle();
    expect(prefs.values[AppConstants.prefsThemePaletteKey], 'indigo');
  });
}

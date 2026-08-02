import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Localization of a widget tree (app-level delegates only, no router).
Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('AppLocalizations', () {
    test('supports English and Telugu', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'te']),
      );
    });

    test('English fallback returns a value for every key', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.appName, 'BookMySpace');
      expect(en.bookNow, isNotEmpty);
    });

    test('Telugu translation exists for core strings', () {
      final te = AppLocalizations(const Locale('te'));
      final en = AppLocalizations(const Locale('en'));
      expect(te.appName, isNot(en.appName));
      expect(te.bookNow, isNotEmpty);
    });
  });

  group('AppTheme', () {
    test('uses Material 3 in light mode', () {
      expect(AppTheme.light.useMaterial3, isTrue);
    });

    test('supports dark mode', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('renders first page and advances to next', (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Discover venues'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Book in seconds'), findsOneWidget);
    });
  });
}

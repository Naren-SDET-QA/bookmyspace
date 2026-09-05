import 'package:bookmyspace/core/config/settings_controller.dart';
import 'package:bookmyspace/core/constants/app_constants.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/features/auth/domain/auth_configuration.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import 'package:bookmyspace/features/auth/presentation/screens/login_screen.dart';
import 'package:bookmyspace/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:bookmyspace/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/mock_auth_repository.dart';

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
    test('supports English, Hindi, Telugu and restored locales', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll([
          'en',
          'te',
          'hi',
          'ta',
          'kn',
          'mr',
          'bn',
          'gu',
          'ml',
          'es',
        ]),
      );
    });

    test('restored locales translate core keys and fall back to English', () {
      const codes = ['ta', 'kn', 'mr', 'bn', 'gu', 'ml', 'es'];
      final en = AppLocalizations(const Locale('en'));
      for (final code in codes) {
        final l10n = AppLocalizations(Locale(code));
        expect(l10n.bookNow, isNotEmpty);
        expect(l10n.bookNow, isNot(en.bookNow), reason: code);
        expect(l10n.privacyPolicy, en.privacyPolicy, reason: code);
        expect(AppLocalizations.languageLabel(Locale(code)), isNot(code));
      }
    });

    test('Hindi falls back to English for missing keys', () {
      final hi = AppLocalizations(const Locale('hi'));
      final en = AppLocalizations(const Locale('en'));
      expect(hi.appName, isNot(en.appName));
      expect(hi.bookNow, isNotEmpty);
      expect(hi.privacyPolicy, en.privacyPolicy);
      expect(hi.viewOnMap, isNot(en.viewOnMap));
      expect(hi.unifiedRegistration, isNot(en.unifiedRegistration));
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

    test(
      'localized profile navigation labels resolve in supported locales',
      () {
        for (final locale in AppLocalizations.supportedLocales) {
          final l10n = AppLocalizations(locale);
          expect(l10n.settings, isNotEmpty);
          expect(l10n.notifications, isNotEmpty);
          expect(l10n.ownerDashboard, isNotEmpty);
          expect(l10n.instituteOwnerPortal, isNotEmpty);
          expect(l10n.support, isNotEmpty);
        }
      },
    );

    test('high-impact auth, payment and institute labels resolve', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.login, isNotEmpty);
        expect(l10n.paymentHistory, isNotEmpty);
        expect(l10n.createInstitute, isNotEmpty);
        expect(l10n.addFaculty, isNotEmpty);
        expect(l10n.addClass, isNotEmpty);
      }
    });

    test('support labels resolve across supported locales', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = AppLocalizations(locale);
        expect(l10n.support, isNotEmpty);
        expect(l10n.newTicket, isNotEmpty);
        expect(l10n.noSupportTickets, isNotEmpty);
        expect(l10n.cancel, isNotEmpty);
      }
    });

    test('legacy locale set matches supported locales exactly', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toList(),
        ['en', 'te', 'hi', 'ta', 'kn', 'mr', 'bn', 'gu', 'ml', 'es'],
      );
    });

    test('unsupported locale falls back to English strings', () {
      final unknown = AppLocalizations(const Locale('fr'));
      final en = AppLocalizations(const Locale('en'));
      expect(unknown.login, en.login);
      expect(unknown.bookNow, en.bookNow);
      expect(unknown.authUnavailable, en.authUnavailable);
      expect(unknown.quickBookingMode, en.quickBookingMode);
    });

    test('resolve maps missing and unsupported codes to English', () {
      expect(AppLocalizations.resolve(null).languageCode, 'en');
      expect(AppLocalizations.resolve(const Locale('fr')).languageCode, 'en');
      expect(AppLocalizations.resolve(const Locale('te')).languageCode, 'te');
      expect(
        AppLocalizations.resolve(const Locale('hi', 'IN')).languageCode,
        'hi',
      );
    });

    test('login, booking, search, owner and notification keys exist', () {
      final en = AppLocalizations(const Locale('en'));
      final hi = AppLocalizations(const Locale('hi'));
      final te = AppLocalizations(const Locale('te'));
      expect(en.signInHint, isNotEmpty);
      expect(en.orDivider, 'OR');
      expect(en.createProfile, isNotEmpty);
      expect(en.quickBookingMode, isNotEmpty);
      expect(en.bookingDisabledForCategory, isNotEmpty);
      expect(en.allFilters, isNotEmpty);
      expect(en.notAnOwner, isNotEmpty);
      expect(en.payNow, isNotEmpty);
      expect(en.noNotifications, isNotEmpty);
      expect(hi.login, isNot(en.login));
      expect(hi.notAnOwner, isNot(en.notAnOwner));
      expect(te.createProfile, isNot(en.createProfile));
      expect(te.payNow, isNot(en.payNow));
    });

    test('parameterized strings substitute placeholders', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.otpResendIn(12), contains('12'));
      expect(en.fieldsRequired('guests'), contains('guests'));
      expect(en.verifiedResultsCount(3), contains('3'));
      expect(en.inArea('Hotels', 'Hyderabad'), contains('Hotels'));
      expect(en.inArea('Hotels', 'Hyderabad'), contains('Hyderabad'));
      expect(en.minutesAgo(5), contains('5'));
    });

    test('restored locales fall back to English for new screen keys', () {
      final ta = AppLocalizations(const Locale('ta'));
      final en = AppLocalizations(const Locale('en'));
      expect(ta.createProfile, isNot(en.createProfile));
      expect(ta.authUnavailable, en.authUnavailable);
      expect(ta.signInHint, en.signInHint);
    });

    test('locale notifier rejects unknown language codes', () async {
      final prefs = _MemoryPreferences();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(localeProvider).languageCode, 'en');
      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('te'));
      expect(container.read(localeProvider).languageCode, 'te');
      expect(prefs.values[AppConstants.prefsLocaleKey], 'te');

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('zz'));
      expect(container.read(localeProvider).languageCode, 'en');
      expect(prefs.values[AppConstants.prefsLocaleKey], 'en');

      prefs.values[AppConstants.prefsLocaleKey] = 'fr';
      final reloaded = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.read(localeProvider).languageCode, 'en');
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.read(localeProvider).languageCode, 'en');
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

  group('language selector', () {
    testWidgets('lists native labels for every supported locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesProvider.overrideWithValue(_MemoryPreferences()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();

      final labels = <String>{};
      for (var page = 0; page < 4; page++) {
        labels.addAll(
          tester
              .widgetList<ListTile>(find.byType(ListTile))
              .map((tile) => (tile.title as Text?)?.data)
              .whereType<String>(),
        );
        await tester.drag(find.byType(ListView).last, const Offset(0, -300));
        await tester.pump();
      }
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          labels,
          contains(AppLocalizations.languageLabel(locale)),
          reason: locale.languageCode,
        );
      }
    });
  });

  group('login localization', () {
    testWidgets('renders Hindi sign-in copy', (tester) async {
      final hi = AppLocalizations(const Locale('hi'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
            authConfigurationProvider.overrideWith(
              (ref) async => const AuthConfiguration(
                authenticationEnabled: true,
                emailLoginEnabled: true,
                emailOtpEnabled: true,
                signupEnabled: true,
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('hi'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(hi.signInHint), findsOneWidget);
      expect(find.text(hi.orDivider), findsOneWidget);
      expect(find.text(hi.createProfile), findsOneWidget);
    });

    testWidgets('shows localized auth-unavailable message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
            authConfigurationProvider.overrideWith(
              (ref) async =>
                  const AuthConfiguration(authenticationEnabled: false),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Authentication is currently unavailable.'),
        findsOneWidget,
      );
    });
  });
}

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

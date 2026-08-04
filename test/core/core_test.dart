import 'package:bookmyspace/core/config/app_config.dart';
import 'package:bookmyspace/core/errors/app_exceptions.dart';
import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/widgets/empty_state.dart';
import 'package:bookmyspace/core/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  test('development test login is fail-closed outside debug development', () {
    bool allowed(AppEnvironment environment, {bool release = false}) =>
        AppConfig.isDevelopmentTestLoginAllowed(
          environment: environment,
          releaseMode: release,
          profileMode: false,
          email: 'test@example.invalid',
          password: 'test-password',
        );

    expect(allowed(AppEnvironment.development), isTrue);
    expect(allowed(AppEnvironment.development, release: true), isFalse);
    expect(allowed(AppEnvironment.staging), isFalse);
    expect(allowed(AppEnvironment.production), isFalse);
    expect(
      AppConfig.isDevelopmentTestLoginAllowed(
        environment: AppEnvironment.development,
        releaseMode: false,
        profileMode: false,
        email: '',
        password: '',
      ),
      isFalse,
    );
  });
  group('AppConfig', () {
    test('requires explicit Supabase dart-defines', () {
      expect(AppConfig.appName, 'BookMySpace');
      expect(AppConfig.razorpayKeyId, isNotEmpty);
      if (AppConfig.hasSupabaseConfiguration) {
        expect(AppConfig.requireSupabaseConfiguration, returnsNormally);
      } else {
        expect(
          AppConfig.requireSupabaseConfiguration,
          throwsA(isA<StateError>()),
        );
      }
    });
  });

  group('AppExceptions', () {
    test('mapError returns typed exceptions', () {
      expect(mapError(const BusinessException('x')), isA<BusinessException>());
      expect(mapError(const NetworkException('x')), isA<NetworkException>());
      expect(mapError(ArgumentError()), isA<BusinessException>());
      expect(mapError(Exception('boom')), isA<AppError>());
    });
  });

  group('ErrorView', () {
    testWidgets('shows message and retry callback fires', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(ErrorView(message: 'Oops', onRetry: () => retried = true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Oops'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(title: 'Nothing here', message: 'Check back later'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Check back later'), findsOneWidget);
    });
  });
}

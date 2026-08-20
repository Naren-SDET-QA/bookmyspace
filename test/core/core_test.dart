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
  group('AppConfig', () {
    test('exposes the app name and a default environment', () {
      expect(AppConfig.appName, 'BookMySpace');
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.razorpayKeyId, isNotEmpty);
    });

    test('DEV Razorpay configuration uses a public test key when supplied', () {
      if (AppConfig.isDevelopment || AppConfig.isStaging) {
        expect(AppConfig.razorpayKeyId, startsWith('rzp_test_'));
        expect(AppConfig.razorpayKeyId, isNot(contains('secret')));
      }
    });

    test('production does not use a DEV test key override', () {
      expect(
        AppEnvironment.production.toModel().razorpayKeyId,
        isNot(startsWith('rzp_test_')),
      );
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

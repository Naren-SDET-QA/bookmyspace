import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/offline/offline_cached_banner.dart';
import 'package:bookmyspace/core/offline/offline_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides when live data is showing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servingCachedDataProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(body: OfflineCachedBanner()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Showing saved data while you are offline'), findsNothing);
  });

  testWidgets('shows cached copy and retry clears the flag', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servingCachedDataProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: OfflineCachedBanner(onRetry: () => retried = true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Showing saved data while you are offline'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
    expect(find.text('Showing saved data while you are offline'), findsNothing);
  });
}

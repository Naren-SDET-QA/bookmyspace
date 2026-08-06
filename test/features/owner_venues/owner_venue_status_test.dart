import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/features/owner_venues/presentation/providers/owner_venue_providers.dart';
import 'package:bookmyspace/features/owner_venues/presentation/screens/owner_venues_screen.dart';
import 'package:bookmyspace/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Venue _venue({
  required String id,
  required String name,
  bool isActive = false,
  bool isVerified = false,
}) {
  return Venue(
    id: id,
    name: name,
    latitude: 15.5,
    longitude: 80.0,
    isActive: isActive,
    isVerified: isVerified,
  );
}

void main() {
  testWidgets('owner sees Under review for pending hall', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myVenuesProvider.overrideWith(
            (ref) async => [_venue(id: 'v1', name: 'Pending Hall')],
          ),
        ],
        child: const MaterialApp(
          home: OwnerVenuesScreen(),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Hall'), findsOneWidget);
    expect(find.text('⏳ Under review'), findsOneWidget);
  });

  testWidgets('owner sees Live for approved hall', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myVenuesProvider.overrideWith(
            (ref) async => [
              _venue(id: 'v2', name: 'Live Hall', isActive: true),
            ],
          ),
        ],
        child: const MaterialApp(
          home: OwnerVenuesScreen(),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('✅ Live'), findsOneWidget);
  });
}

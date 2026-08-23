import 'package:bookmyspace/core/modular/feature_registry.dart';
import 'package:bookmyspace/features/admin/presentation/screens/admin_feature_configuration_screen.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';
import 'package:bookmyspace/features/venues/presentation/category_configuration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FeatureRegistry.reset);
  tearDown(FeatureRegistry.reset);

  testWidgets(
    'admin features page groups configuration for a non-technical admin',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryConfigurationsProvider.overrideWith(
              (ref) async => const <CategoryConfiguration>[],
            ),
          ],
          child: const MaterialApp(home: AdminFeatureConfigurationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feature configuration'), findsOneWidget);
      for (final label in const [
        'Features',
        'Categories',
        'Booking',
        'Offers',
        'AI & Voice',
        'Map',
        'Payments',
        'Invoice',
        'Notifications',
        'QR/Barcode',
        'Analytics',
        'Theme',
      ]) {
        expect(find.text(label), findsWidgets, reason: 'missing group $label');
      }
    },
  );
}

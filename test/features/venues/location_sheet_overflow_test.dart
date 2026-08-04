import 'package:bookmyspace/core/localization/app_localizations.dart';
import 'package:bookmyspace/core/theme/app_theme.dart';
import 'package:bookmyspace/core/theme/prototype_visuals.dart';
import 'package:bookmyspace/core/widgets/app_bottom_sheet.dart';
import 'package:bookmyspace/features/venues/presentation/venue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Choose location sheet does not overflow at short viewport heights',
    (tester) async {
      tester.view.physicalSize = const Size(390, 520);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        final msg = details.toString();
        if (msg.contains('OVERFLOWED') || msg.contains('overflowed')) {
          errors.add(details);
        }
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () {
                        final current = kDefaultSearchArea;
                        showAppBottomSheet<void>(
                          context: context,
                          maxHeightFactor: 0.78,
                          builder: (sheetContext) {
                            return ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                              children: [
                                Text(
                                  'Choose location',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 10),
                                const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.my_location_rounded),
                                  title: Text('Use my current location'),
                                  subtitle: Text(
                                    'Uses GPS to find venues near you',
                                  ),
                                ),
                                for (final entry in kSearchCities.entries)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.key),
                                    trailing:
                                        entry.value.cityLabel ==
                                            current.cityLabel
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppTheme.brand,
                                          )
                                        : null,
                                  ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text('Open location'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open location'));
      await tester.pumpAndSettle();

      expect(find.text('Choose location'), findsOneWidget);
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Guntur'), findsOneWidget);

      await tester.drag(find.text('Choose location'), const Offset(0, -220));
      await tester.pumpAndSettle();

      expect(errors, isEmpty, reason: errors.toString());
    },
  );

  testWidgets('prototype category tiles render exact emojis without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.toString();
      if (msg.contains('OVERFLOWED') || msg.contains('overflowed')) {
        errors.add(details);
      }
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.88,
              ),
              itemCount: PrototypeVisuals.homeCategories.length,
              itemBuilder: (context, index) {
                final item = PrototypeVisuals.homeCategories[index];
                return PrototypeCategoryTile(
                  emoji: item.emoji,
                  label: item.label,
                  onTap: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final cat in PrototypeVisuals.homeCategories) {
      expect(find.text(cat.label), findsOneWidget);
      expect(find.text(cat.emoji), findsOneWidget);
    }
    expect(find.byType(PrototypeCategoryTile), findsNWidgets(8));
    expect(errors, isEmpty, reason: errors.toString());
  });

  testWidgets('showAppBottomSheet constrains height under maxHeightFactor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    showAppBottomSheet<void>(
                      context: context,
                      maxHeightFactor: 0.7,
                      builder: (_) => ListView(
                        children: List.generate(
                          40,
                          (i) => ListTile(title: Text('Row $i')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final constrained = tester.widgetList<ConstrainedBox>(
      find.byType(ConstrainedBox),
    );
    final capped = constrained.where(
      (c) =>
          c.constraints.maxHeight.isFinite &&
          c.constraints.maxHeight <= 640 * 0.7 + 0.5,
    );
    expect(capped, isNotEmpty);
    expect(find.text('Row 0'), findsOneWidget);
  });
}

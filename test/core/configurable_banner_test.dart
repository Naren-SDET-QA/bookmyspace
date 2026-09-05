import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/widgets/configurable_banner.dart';

void main() {
  testWidgets('banner renders configured text and tolerates invalid colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfigurableBanner(
            settings: {
              'banner_text': 'Reserve today',
              'banner_background': 'bad-color',
              'banner_text_color': '#11223344',
            },
          ),
        ),
      ),
    );
    expect(find.text('Reserve today'), findsOneWidget);
  });
}

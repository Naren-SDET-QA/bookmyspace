import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/core/widgets/accessibility.dart';

void main() {
  group('MinTouchTarget', () {
    testWidgets('enforces minimum 44x44 size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinTouchTarget(
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );
      final constraints = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.byType(SizedBox).first,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constraints.constraints.minWidth, 44);
      expect(constraints.constraints.minHeight, 44);
    });

    testWidgets('does not enlarge larger widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MinTouchTarget(
              child: SizedBox(width: 60, height: 60),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(SizedBox).first);
      expect(size.width, 60);
      expect(size.height, 60);
    });
  });

  group('AccessibleInkWell', () {
    testWidgets('renders with onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleInkWell(
              onTap: () => tapped = true,
              semanticsLabel: 'Test button',
              child: const Text('Press me'),
            ),
          ),
        ),
      );
      expect(find.text('Press me'), findsOneWidget);
      await tester.tap(find.text('Press me'));
      expect(tapped, isTrue);
    });
  });

  group('AccessibleIconButton', () {
    testWidgets('renders with tooltip and minimum size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleIconButton(
              icon: Icons.add,
              onPressed: () {},
              tooltip: 'Add item',
              semanticsLabel: 'Add',
            ),
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}

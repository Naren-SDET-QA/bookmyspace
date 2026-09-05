import 'package:bookmyspace/core/offline/offline_store.dart';
import 'package:bookmyspace/features/support/domain/contextual_help.dart';
import 'package:bookmyspace/features/support/presentation/widgets/contextual_help_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog maps booking and payment routes without using AI/KB articles', () {
    expect(ContextualHelpCatalog.forRoute('/home')?.id, 'home');
    expect(ContextualHelpCatalog.forRoute('/search')?.id, 'search');
    expect(ContextualHelpCatalog.forRoute('/venues/abc/book')?.id, 'booking');
    expect(ContextualHelpCatalog.forRoute('/bookings/xyz/pay')?.id, 'pay');
    expect(ContextualHelpCatalog.forRoute('/owner')?.id, 'owner');
  });

  test('dismissed topics persist and can be restored', () async {
    final store = ContextualHelpStore(MemoryOfflineStore());
    expect(await store.isDismissed('search'), isFalse);
    await store.dismiss('search');
    expect(await store.isDismissed('search'), isTrue);
    await store.restore('search');
    expect(await store.isDismissed('search'), isFalse);
  });

  testWidgets('help button opens persisted topic', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [ContextualHelpButton(route: '/search')],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('contextual_help_button')));
    await tester.pumpAndSettle();
    expect(find.text('Search tips'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });
}

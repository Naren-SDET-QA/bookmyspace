import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/universal_intent.dart';

void main() {
  test('parses a provider-neutral search intent without trusting identity fields', () {
    final intent = UniversalIntent.fromMap({
      'intent': 'SEARCH',
      'category': 'sports_court',
      'location': 'Hyderabad',
      'user_id': 'attacker',
      'price': 1,
    });
    expect(intent.kind, UniversalIntentKind.search);
    expect(intent.category, 'sports_court');
    expect(intent.location, 'Hyderabad');
    expect(intent.untrustedFields, containsAll(['user_id', 'price']));
  });

  test('treats all client financial authority fields as untrusted', () {
    final intent = UniversalIntent.fromMap({
      'intent': 'SEARCH',
      'tax': 10,
      'base_price': 100,
      'fees': 5,
      'total': 115,
      'currency': 'USD',
    });

    expect(
      intent.untrustedFields,
      containsAll(['tax', 'base_price', 'fees', 'total', 'currency']),
    );
    expect(intent.values, isNot(contains('tax')));
    expect(intent.values, isNot(contains('total')));
  });

  test('unknown intent is rejected instead of becoming a booking action', () {
    expect(() => UniversalIntent.fromMap({'intent': 'MAKE_MAGIC_BOOKING'}), throwsFormatException);
  });

  test('missing configured fields produce clarification without guessing', () {
    const intent = UniversalIntent(kind: UniversalIntentKind.availability, category: 'hotel');
    final result = intent.validate(requiredFields: const ['check_in', 'check_out', 'guests']);
    expect(result.isValid, isFalse);
    expect(result.missingFields, ['check_in', 'check_out', 'guests']);
    expect(result.question, contains('check in'));
  });

  test('financial actions require explicit confirmation', () {
    const intent = UniversalIntent(kind: UniversalIntentKind.confirmBooking);
    expect(intent.requiresConfirmation, isTrue);
    expect(intent.validate(requiredFields: const [], confirmed: false).isValid, isFalse);
  });
}

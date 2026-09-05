import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/ai/domain/dynamic_clarification_flow.dart';
import 'package:bookmyspace/features/ai/domain/dynamic_clarification.dart';
import 'package:bookmyspace/features/venues/domain/category_configuration.dart';

void main() {
  final sports = CategoryConfiguration(
    id: 'sports-id',
    slug: 'sports_court',
    name: 'Sports Court',
    requiredFields: const ['booking_type', 'date'],
    optionalFields: const ['meeting_type'],
  );

  test('discovers a configured category and reports the first missing field', () {
    final flow = DynamicClarificationFlow([sports]);
    final result = flow.start('book a sports court');

    expect(result.status, ClarificationResultStatus.missingFields);
    expect(result.category?.slug, 'sports_court');
    expect(result.missingFields.first.key, 'booking_type');
  });

  test('conditional fields are recalculated after an answer', () {
    final schema = DynamicFieldSchema.fromMetadata({
      'fields': [
        {'key': 'booking_type', 'label': 'Booking type', 'type': 'dropdown', 'required': true, 'options': ['online', 'onsite']},
        {'key': 'meeting_type', 'label': 'Meeting type', 'type': 'text', 'required': true, 'when': {'field': 'booking_type', 'equals': 'online'}},
      ],
    });
    final flow = DynamicClarificationFlow([sports]);
    final state = ClarificationState.create(userId: 'u', sessionId: 's', categorySlug: sports.slug, requiredFields: schema.requiredKeys);
    final updated = flow.answer(state, 'booking_type', 'online', schema: schema);

    expect(updated.missingFields, contains('meeting_type'));
  });

  test('correction replaces an answer and invalidates readiness', () {
    final flow = DynamicClarificationFlow([sports]);
    final state = flow.start('book a sports court').state!;
    final answered = flow.answer(state, 'booking_type', 'onsite');
    final corrected = flow.answer(answered, 'booking_type', null);

    expect(corrected.values.containsKey('booking_type'), isFalse);
    expect(corrected.missingFields, contains('booking_type'));
  });

  test('hidden categories and invalid options are rejected safely', () {
    final hidden = CategoryConfiguration(
      id: sports.id,
      slug: sports.slug,
      name: sports.name,
      visible: false,
    );
    final flow = DynamicClarificationFlow([hidden]);
    expect(flow.start('book a sports court').status, ClarificationResultStatus.categoryNotFound);
    expect(() => flow.validateOption('x', const ['a', 'b']), throwsA(isA<FormatException>()));
  });
}
